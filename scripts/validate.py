from pathlib import Path
import json
from tree_sitter import Language, Parser
import tree_sitter_swift
import yaml

root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
errors = []
for path in [*root.glob('Lekapro/*.swift'), *root.glob('LekaproTests/*.swift')]:
    tree = parser.parse(path.read_bytes())
    if tree.root_node.has_error:
        stack = [tree.root_node]
        while stack:
            node = stack.pop()
            if node.type == 'ERROR' or node.is_missing:
                errors.append(f'{path.name}:{node.start_point.row + 1}: {node.type}')
            stack.extend(node.children)
project = yaml.safe_load((root/'project.yml').read_text(encoding='utf-8'))
workflow = yaml.safe_load((root/'.github/workflows/ios.yml').read_text(encoding='utf-8'))
assert project['targets']['Lekapro']['type'] == 'application'
assert workflow['jobs']['build']['runs-on'].startswith('macos')
assert 'CODE_SIGNING_ALLOWED=NO' in (root/'.github/workflows/ios.yml').read_text()
for path in root.glob('Lekapro/Assets.xcassets/**/Contents.json'):
    json.loads(path.read_text())
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Syntax validation passed for {len(list(root.rglob("*.swift")))} Swift files; YAML and asset JSON valid.')
print('This does not replace compilation against the iOS SDK or simulator tests.')
