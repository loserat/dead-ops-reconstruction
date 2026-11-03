"""Package the locally signed Mac preview without developer tools or user data.

Build first with ./build.sh mac. This is an ad-hoc-signed, non-notarized
preview; Developer ID distribution requires a separate signing workflow.
"""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def sha(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=ROOT/'Build/Mac/DeadOpsReconstruction.app')
    parser.add_argument('--output', type=Path, default=ROOT/'Build/Downloads')
    parser.add_argument('--source-commit', help='Git commit used to build the unchanged game sources')
    args = parser.parse_args()
    version = (ROOT/'VERSION').read_text().strip()
    assert re.fullmatch(r'0\.\d+', version), 'Invalid VERSION'
    app = args.app.resolve()
    assert app.is_dir() and app.suffix == '.app' and not app.is_symlink()
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == version
    assert info['LSMinimumSystemVersion'] == '14.0'
    executable = app/'Contents/MacOS'/info['CFBundleExecutable']
    arch = subprocess.check_output(['/usr/bin/lipo', '-archs', str(executable)], text=True).strip()
    assert arch == 'arm64', arch
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)])
    signature = subprocess.run(['/usr/bin/codesign', '-d', '--verbose=2', str(app)], capture_output=True, text=True, check=True)
    assert 'Signature=adhoc' in signature.stderr, 'This packager is for the ad-hoc preview only'
    resources = app/'Contents/Resources'
    expected = {f'Assets/{p.name}': sha(p) for p in (ROOT/'Assets').glob('*.png')}
    expected['DeadOps.icns'] = sha(ROOT/'Assets/DeadOps.icns')
    actual = {str(p.relative_to(resources)): sha(p) for p in resources.rglob('*') if p.is_file()}
    assert len(expected) == 15 and actual == expected, 'Unexpected or missing resources, including optional user music'
    assert not any(p.is_symlink() for p in app.rglob('*')), 'External bundle links are not allowed'
    commit = args.source_commit or subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    assert re.fullmatch(r'[0-9a-f]{40}', commit), 'Use a full source commit SHA'
    run(['git', 'diff', '--quiet', commit, '--', 'Sources', 'Assets', 'Config', 'VERSION', 'build.sh'], cwd=ROOT)
    args.output.mkdir(parents=True, exist_ok=True)
    output = args.output.resolve()
    archive = output/f'DeadOps-Reconstruction-{version}-macOS-arm64.zip'
    sums = output/'SHA256SUMS.txt'
    assert not archive.exists() and not sums.exists(), 'Do not overwrite an existing release'
    manifest = {'version': version, 'source_commit': commit, 'architecture': arch,
                'minimum_macos': '14.0', 'signature': 'ad-hoc', 'notarized': False,
                'executable_sha256': sha(executable), 'resources_sha256': actual,
                'developer_tools_required_to_play': False}
    with tempfile.TemporaryDirectory(prefix='DeadOps-package-', dir=output) as temp:
        stage = Path(temp)/f'DeadOps-Reconstruction-{version}'
        stage.mkdir()
        friendly_app = stage/'Dead Ops Reconstruction.app'
        run(['/usr/bin/ditto', '--norsrc', '--noextattr', '--noqtn', '--noacl', str(app), str(friendly_app)])
        run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(friendly_app)])
        (stage/'Release-Info.json').write_text(json.dumps(manifest, indent=2)+'\n')
        (stage/'LIESMICH.txt').write_text(f'''DEAD OPS RECONSTRUCTION {version} – MAC-VORABVERSION

Voraussetzung: Mac mit Apple-Chip (M1 oder neuer), macOS 14 oder neuer.
Zum Spielen brauchst du weder Xcode noch Python.

1. Ziehe „Dead Ops Reconstruction.app“ in deinen Ordner „Programme“.
2. Öffne die App. Bewegen: WASD. Zielen/Schießen: Pfeiltasten.
   Boost: Leertaste. Bombe: B. Pause: Escape.
   Controller: linker/rechter Stick, R1/R2 für Boost, L1/L2 für Bombe.

Diese Vorabversion ist lokal signiert und noch nicht von Apple notarisiert.
Bei einer entsprechenden Startblockierung kannst du diese einzelne App
über Systemeinstellungen > Datenschutz & Sicherheit > Dennoch öffnen
freigeben, wenn du diesem Download vertraust.
Apples Erläuterung: https://support.apple.com/de-de/102445

Anleitung und Grenzen:
https://github.com/loserat/dead-ops-reconstruction/blob/main/docs/INSTALLATION.md

Die Darstellung und Leistung sind noch in Entwicklung. Ein aktueller
Fremd-Mac-, physischer Controller- oder Apple-TV-Test ist nicht zugesichert.
''')
        run(['/usr/bin/ditto', '-c', '-k', '--norsrc', '--noextattr', '--noqtn', '--keepParent', str(stage), str(archive)])
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.testzip() is None
        assert all(not n.startswith('/') and '..' not in Path(n).parts for n in zipped.namelist())
        assert not any('__MACOSX' in Path(n).parts or Path(n).name.startswith('._') for n in zipped.namelist())
        assert len([n for n in zipped.namelist() if n.endswith('/Contents/Info.plist')]) == 1
    digest = sha(archive)
    sums.write_text(f'{digest}  {archive.name}\n')
    print(json.dumps({'archive': str(archive), 'bytes': archive.stat().st_size,
                      'sha256': digest, 'checksums': str(sums), **manifest}, indent=2))


if __name__ == '__main__':
    main()
