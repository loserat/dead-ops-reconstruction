"""Check the Git index (and optionally history) before publishing.

Reports filenames and finding categories, never matched secret values.
Xcode's project.pbxproj is checked for location/size/mode but kept opaque;
personal signing settings must also be reviewed through Xcode.
"""
from pathlib import Path, PurePosixPath
import argparse
import json
import re
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET
import zlib

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {'.gitignore', '.gitattributes', 'README.md', 'CHANGELOG.md',
              'CONTRIBUTING.md', 'LICENSE.md', 'VERSION', 'build.sh'}
PROJECT_FILES = {
    'DeadOpsReconstruction.xcodeproj/project.pbxproj',
    'DeadOpsReconstruction.xcodeproj/project.xcworkspace/contents.xcworkspacedata',
    'DeadOpsReconstruction.xcodeproj/xcshareddata/xcschemes/Dead Ops Mac.xcscheme',
    'DeadOpsReconstruction.xcodeproj/xcshareddata/xcschemes/Dead Ops Apple TV.xcscheme',
}
PATTERNS = {
    'private-key material': rb'-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----',
    'GitHub credential': rb'(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{30,})',
    'provider credential': rb'sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}',
    'AWS credential identifier': rb'(?:AKIA|ASIA)[A-Z0-9]{16}',
    'personal home path': rb'/(?:Users|home)/[^/\s\x00]+/',
    'personal temporary path': rb'/var/folders/[A-Za-z0-9/_.-]+',
    'private network address': rb'192\.168\.[0-9]+\.[0-9]+',
    'credentials in URL': rb'https?://[^\s/@:]+:[^\s/@]+@',
}


def allowed(name):
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts:
        return False
    if name in ROOT_FILES or name in PROJECT_FILES:
        return True
    if len(p.parts) == 2:
        folder, filename = p.parts
        return ((folder == 'Sources' and p.suffix == '.swift') or
                (folder == 'Tests' and (p.suffix == '.swift' or filename == 'check.sh')) or
                (folder == 'Config' and filename in {'Info-mac.plist', 'Info-tvOS.plist'}) or
                (folder == 'Assets' and (p.suffix == '.png' or filename == 'DeadOps.icns')) or
                (folder == 'docs' and p.suffix in {'.md', '.json'}) or
                (folder == 'scripts' and p.suffix == '.py'))
    return (name in {'Assets/AppIcon/DeadOps-Icon.png', 'Assets/Music/LESEN.txt'} or
            (p.parts[:2] == ('docs', 'images') and len(p.parts) == 3 and p.suffix in {'.png', '.svg'}))


def scan_text(data):
    return [kind for kind, pattern in PATTERNS.items() if re.search(pattern, data)]


def inflate(data):
    decoder = zlib.decompressobj()
    result = decoder.decompress(data, 1_048_577)
    if len(result) > 1_048_576 or not decoder.eof or decoder.unused_data:
        raise ValueError('oversized or invalid compressed metadata')
    return result


def png_metadata(data):
    """Inspect text/compressed text and EXIF owner/GPS tags without editing pixels."""
    findings = []
    pos = 8
    while pos + 12 <= len(data):
        size = struct.unpack('>I', data[pos:pos+4])[0]
        kind, payload = data[pos+4:pos+8], data[pos+8:pos+8+size]
        if pos + size + 12 > len(data):
            return findings + ['invalid PNG structure']
        if kind in {b'tEXt', b'zTXt', b'iTXt'}:
            keyword, content = payload.split(b'\0', 1)
            if keyword.lower() in {b'author', b'artist', b'owner', b'gps', b'location'}:
                findings.append('author or location text field')
            if kind == b'zTXt':
                content = inflate(content[1:])
            elif kind == b'iTXt':
                compressed = content[0]
                _, _, content = content[2:].split(b'\0', 2)
                if compressed:
                    content = inflate(content)
            findings += scan_text(content)
            if kind == b'iTXt' and content.lstrip().startswith(b'<'):
                tree = ET.fromstring(content)
                for element in tree.iter():
                    for field in [element.tag, *element.attrib]:
                        key = field.rsplit('}', 1)[-1].lower()
                        if key.startswith('gps') or key in {'creator', 'artist', 'ownername', 'cameraownername', 'bodyserialnumber', 'lensserialnumber'}:
                            findings.append('XMP owner, serial or location field')
        if kind == b'eXIf':
            endian = '<' if payload[:2] == b'II' else '>'
            if payload[:2] not in {b'II', b'MM'}:
                return findings + ['invalid EXIF structure']
            visited = set()

            def ifd(offset):
                if not offset or offset in visited:
                    return
                visited.add(offset)
                count = struct.unpack_from(endian+'H', payload, offset)[0]
                for i in range(count):
                    tag, _, _, value = struct.unpack_from(endian+'HHII', payload, offset+2+12*i)
                    if tag in {0x013b, 0x013c, 0x8825, 0xa430, 0xa431, 0xa435}:
                        findings.append('EXIF owner, serial or location field')
                    if tag in {0x8769, 0x8825}:
                        ifd(value)
                ifd(struct.unpack_from(endian+'I', payload, offset+2+12*count)[0])

            ifd(struct.unpack_from(endian+'I', payload, 4)[0])
        pos += size + 12
        if kind == b'IEND':
            if pos != len(data):
                findings.append('extra data after PNG end')
            return findings
    return findings + ['missing PNG end']


def scan_blob(name, data):
    problems = scan_text(data)
    suffix = PurePosixPath(name).suffix
    if suffix == '.png':
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):
            return problems + ['invalid PNG file']
        return problems + png_metadata(data)
    if suffix == '.icns':
        return problems + ([] if data[:4] == b'icns' else ['invalid icon file'])
    text = data.decode('utf-8')
    if '\x00' in text:
        problems.append('unexpected binary content')
    if suffix == '.json':
        json.loads(text)
    if suffix in {'.svg', '.plist', '.xcscheme', '.xcworkspacedata'}:
        tree = ET.fromstring(text)
        if suffix == '.svg':
            if '<!DOCTYPE' in text.upper() or '<!ENTITY' in text.upper():
                problems.append('active SVG declaration')
            for node in tree.iter():
                if node.tag.rsplit('}', 1)[-1] in {'script', 'foreignObject'}:
                    problems.append('active SVG element')
                for key, value in node.attrib.items():
                    if key.lower().startswith('on') or (key.endswith('href') and not value.startswith('#')):
                        problems.append('active or external SVG reference')
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true', help='also check every locally available commit')
    parser.add_argument('--repo', type=Path, default=ROOT)
    parser.add_argument('--report', type=Path, help='write a local JSON report outside tracked files')
    args = parser.parse_args()
    root = args.repo.resolve()

    def git(*argv):
        return subprocess.check_output(['git', *argv], cwd=root)

    index = []
    for row in git('ls-files', '--stage', '-z').split(b'\0'):
        if row:
            meta, name = row.split(b'\t', 1)
            mode, oid, stage = meta.decode().split()
            index.append((name.decode(), mode, oid, stage))
    rows = [(name, mode, oid, stage, 'index') for name, mode, oid, stage in index]
    commits = git('rev-list', '--all').decode().splitlines() if args.history else []
    for commit in commits:
        for row in git('ls-tree', '-r', '-z', commit).split(b'\0'):
            if row:
                meta, name = row.split(b'\t', 1)
                mode, _, oid = meta.decode().split()
                rows.append((name.decode(), mode, oid, '0', commit[:12]))
    findings, seen, opaque = [], set(), set()
    for name, mode, oid, stage, origin in rows:
        issues = []
        if not allowed(name):
            issues.append('unapproved publication path')
        if mode not in {'100644', '100755'} or stage != '0':
            issues.append('link, submodule or unresolved merge')
        if issues:
            findings.append({'path': name, 'origin': origin, 'findings': issues})
            continue
        if (name, oid) in seen:
            continue
        seen.add((name, oid))
        size = int(git('cat-file', '-s', oid))
        if size > 8_000_000:
            issues.append('file larger than 8 MB; review before publishing')
        elif name.endswith('/project.pbxproj'):
            opaque.add(oid)
        else:
            try:
                issues.extend(scan_blob(name, git('cat-file', 'blob', oid)))
            except (UnicodeError, ValueError, KeyError, IndexError, struct.error, ET.ParseError, zlib.error):
                issues.append('invalid or unreadable file format')
        if issues:
            findings.append({'path': name, 'origin': origin, 'findings': sorted(set(issues))})
    report = {'indexed_files': len(index), 'history_commits': len(commits),
              'file_revisions_checked': len(seen), 'findings': findings,
              'xcode_project_revisions_kept_opaque': len(opaque),
              'limits': 'Pattern and file-policy checks; no malware or licensing guarantee. Review signing settings through Xcode separately.'}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))
    return bool(findings)


if __name__ == '__main__':
    sys.exit(main())
