"""Check local documentation links without fetching or executing external content."""
from pathlib import Path
from html.parser import HTMLParser
import re
import sys
from urllib.parse import unquote, urldefrag

root = Path(__file__).resolve().parents[1]


class HtmlReferences(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []

    def handle_starttag(self, tag, attrs):
        attribute = {'img': 'src', 'a': 'href'}.get(tag)
        target = dict(attrs).get(attribute)
        if target:
            self.targets.append(target)


documents = list(root.glob('*.md')) + list((root / 'docs').rglob('*.md'))
errors = []
count = 0
fragments = 0


def heading_ids(path):
    identifiers, occurrences = set(), {}
    for heading in re.findall(r'^#{1,6}\s+(.+)$', path.read_text(), re.MULTILINE):
        slug = re.sub(r'[^\w\s-]', '', heading.lower()).replace(' ', '-')
        duplicate = occurrences.get(slug, 0)
        identifiers.add(slug if duplicate == 0 else f'{slug}-{duplicate}')
        occurrences[slug] = duplicate + 1
    return identifiers


for path in documents:
    content = path.read_text()
    html = HtmlReferences()
    html.feed(content)
    targets = re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', content) + html.targets
    for target in targets:
        if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:', target):
            continue
        filename, fragment = urldefrag(target)
        resolved = (path.parent / unquote(filename)).resolve() if filename else path
        if filename:
            count += 1
        if not resolved.is_relative_to(root) or not resolved.exists():
            errors.append(f'{path.relative_to(root)}: {target}')
        elif fragment and resolved.suffix == '.md':
            fragments += 1
            if unquote(fragment) not in heading_ids(resolved):
                errors.append(f'{path.relative_to(root)}: unknown section {target}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f'PASS {len(documents)} documents, {count} local paths, {fragments} section links')
