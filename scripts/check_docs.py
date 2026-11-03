"""Check local documentation links without fetching or executing external content."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

root = Path(__file__).resolve().parents[1]
documents = list(root.glob('*.md')) + list((root / 'docs').rglob('*.md'))
errors = []
count = 0
for path in documents:
    for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', path.read_text()):
        target = target.split('#', 1)[0]
        if not target or re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target):
            continue
        resolved = (path.parent / unquote(target)).resolve()
        count += 1
        if not resolved.is_relative_to(root) or not resolved.exists():
            errors.append(f'{path.relative_to(root)}: {target}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f'PASS {len(documents)} documents, {count} local links')
