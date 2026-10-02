from pathlib import Path
import json, re, wave, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
errors = []
class_names = {}
for path in ROOT.rglob('*.gd'):
    text = path.read_text(errors='ignore')
    for match in re.finditer(r'(?:preload|load)\("(res://[^\"]+)"\)', text):
        target = ROOT / match.group(1)[6:]
        if not target.exists():
            errors.append(f'{path}: missing {match.group(1)}')
    declared_class = re.search(r'^class_name\s+([A-Za-z_][A-Za-z0-9_]*)', text, re.M)
    if declared_class:
        class_name = declared_class.group(1)
        if class_name in class_names:
            errors.append(f'{path}: duplicate class_name {class_name} also in {class_names[class_name]}')
        class_names[class_name] = path
    functions = re.findall(r'^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(', text, re.M)
    seen_functions = set()
    for function_name in functions:
        if function_name in seen_functions:
            errors.append(f'{path}: duplicate function {function_name}')
        seen_functions.add(function_name)
    # Lightweight delimiter check; this is not a substitute for Godot's parser.
    stack = []
    quote = None
    escaped = False
    in_comment = False
    pairs = {')': '(', ']': '[', '}': '{'}
    for line_number, line in enumerate(text.splitlines(), 1):
        in_comment = False
        for char in line:
            if in_comment:
                break
            if quote:
                if escaped:
                    escaped = False
                elif char == '\\':
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char in ('"', "'"):
                quote = char
            elif char == '#':
                in_comment = True
            elif char in '([{':
                stack.append((char, line_number))
            elif char in ')]}':
                if not stack or stack[-1][0] != pairs[char]:
                    errors.append(f'{path}:{line_number}: unmatched {char}')
                    break
                stack.pop()
    if quote:
        errors.append(f'{path}: unterminated string literal')
    if stack:
        errors.append(f'{path}:{stack[-1][1]}: unclosed {stack[-1][0]}')
for path in ROOT.rglob('*.json'):
    try:
        json.loads(path.read_text())
    except Exception as exc:
        errors.append(f'{path}: invalid JSON: {exc}')
words_path = ROOT / 'data/words/words.json'
if words_path.exists():
    try:
        word_ids = {str(item.get('id', '')).upper() for item in json.loads(words_path.read_text()) if isinstance(item, dict)}
        world_text = (ROOT / 'world/world.gd').read_text()
        consequence_match = re.search(r'func _apply_word_consequence_local\(normalized: String\) -> void:(.*?)\nfunc ', world_text, re.S)
        if consequence_match:
            consequence_block = consequence_match.group(1)
            for word_id in sorted(word_ids):
                if f'"{word_id}"' not in consequence_block:
                    errors.append(f'word catalog entry {word_id} has no world consequence mapping')
        resume_match = re.search(r'func resume_saved_word\(word: String\) -> void:(.*?)\nfunc apply_persistent_state', world_text, re.S)
        if resume_match:
            resume_block = resume_match.group(1)
            for word_id in sorted(word_ids):
                if f'"{word_id}"' not in resume_block:
                    errors.append(f'word catalog entry {word_id} has no saved-letter resume anchors')
    except Exception as exc:
        errors.append(f'{words_path}: could not audit word-to-world coverage: {exc}')
for path in ROOT.rglob('*.svg'):
    try:
        ET.parse(path)
    except Exception as exc:
        errors.append(f'{path}: invalid SVG: {exc}')
for path in ROOT.rglob('*.png'):
    if not path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'):
        errors.append(f'{path}: invalid PNG signature')
for path in (ROOT / 'audio').rglob('*.wav'):
    try:
        with wave.open(str(path), 'rb') as stream:
            if stream.getnchannels() < 1 or stream.getframerate() < 8000:
                errors.append(f'{path}: invalid WAV')
    except Exception as exc:
        errors.append(f'{path}: invalid WAV: {exc}')

# Keep Android identity/version metadata synchronized across all release surfaces.
project_text = (ROOT / 'project.godot').read_text()
export_text = (ROOT / 'export_presets.cfg').read_text()
config_text = (ROOT / 'core/configuration/game_config.gd').read_text()
main_scene_match = re.search(r'run/main_scene="(res://[^"]+)"', project_text)
if main_scene_match and not (ROOT / main_scene_match.group(1)[6:]).exists():
    errors.append(f'project.godot: missing main scene {main_scene_match.group(1)}')
for scene_path in ROOT.rglob('*.tscn'):
    scene_text = scene_path.read_text(errors='ignore')
    for match in re.finditer(r'(?:path|load_path)="(res://[^"]+)"', scene_text):
        if not (ROOT / match.group(1)[6:]).exists():
            errors.append(f'{scene_path}: missing resource {match.group(1)}')
# project.godot must declare config_version=5 *before* the first section; without it Godot 4 treats
# the project as a Godot 3 project and offers a conversion instead of opening it.
first_section_match = re.search(r'^\[', project_text, re.M)
first_section = first_section_match.start() if first_section_match else -1
version_line = re.search(r'^config_version=5\s*$', project_text, re.M)
if not version_line or (first_section != -1 and version_line.start() > first_section):
    errors.append('project.godot: config_version=5 missing or placed after the first section')
if re.search(r'^\[android\]', project_text, re.M):
    errors.append('project.godot: [android] is not a valid project.godot section (use export_presets.cfg)')
# Android identity lives in the export preset (and mirrored in game_config.gd), not in project.godot.
for label, content in [('export_presets.cfg', export_text), ('game_config.gd', config_text)]:
    if 'com.chastechgroup.alphacrush' not in content:
        errors.append(f'{label}: Android package identity missing')
project_version = re.search(r'config/version="([^"]+)"', project_text)
export_version = re.search(r'version/name="([^"]+)"', export_text)
config_version = re.search(r'VERSION_NAME := "([^"]+)"', config_text)
if not project_version or not export_version or not config_version or len({project_version.group(1), export_version.group(1), config_version.group(1)}) != 1:
    errors.append('release version name is not synchronized')
export_code = re.search(r'version/code=(\d+)', export_text)
config_code = re.search(r'VERSION_CODE := (\d+)', config_text)
if not export_code or not config_code or export_code.group(1) != config_code.group(1):
    errors.append('Android version code is not synchronized (export_presets.cfg vs game_config.gd)')
if 'gradle_build/export_format=1' in export_text and 'gradle_build/use_gradle_build=true' not in export_text:
    errors.append('export_presets.cfg: AAB export requires gradle_build/use_gradle_build=true')
runner_text = (ROOT / 'tests/run_tests.gd').read_text()
for match in re.finditer(r'"(res://tests/[^"]+\.gd)"', runner_text):
    if not (ROOT / match.group(1)[6:]).exists():
        errors.append(f'tests/run_tests.gd: missing suite {match.group(1)}')

for suite in sorted((ROOT / 'tests').rglob('test_*.gd')):
    if suite.name not in runner_text:
        errors.append(f'tests/run_tests.gd: suite {suite.name} is not registered')

# Engine-free static checks (undefined functions, Variant `:=`, redeclared locals, member/arity errors).
import subprocess, sys
lint = ROOT / 'tools' / 'gdlint' / 'run_all.py'
if lint.exists():
    result = subprocess.run([sys.executable, str(lint)], capture_output=True, text=True)
    if result.returncode != 0:
        errors.append('gdlint failed:\n' + result.stdout[-1500:])

if errors:
    print('SOURCE AUDIT FAILED')
    for error in errors:
        print(error)
    raise SystemExit(1)

print('SOURCE AUDIT PASSED')
print('GDScript:', len(list(ROOT.rglob('*.gd'))))
print('JSON:', len(list(ROOT.rglob('*.json'))))
print('SVG:', len(list((ROOT / 'assets').rglob('*.svg'))))
print('PNG:', len(list((ROOT / 'assets').rglob('*.png'))))
print('WAV:', len(list((ROOT / 'audio').rglob('*.wav'))))
