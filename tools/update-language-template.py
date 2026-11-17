#!/usr/bin/env python3
"""Rebuilds Resources/Languages/en.json (the English template) from every L("...") and
N("...") text in Sources/, and lists texts missing from the other language files.
Run after adding or changing user-facing texts:  python3 tools/update-language-template.py"""
import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
pattern = re.compile(r'\b[LN]\("((?:[^"\\]|\\.)*)"')
keys = []
for source in sorted((root / "Sources").glob("*.swift")):
    for match in pattern.finditer(source.read_text(encoding="utf-8")):
        key = match.group(1).encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
        if key not in keys:
            keys.append(key)

folder = root / "Resources" / "Languages"
folder.mkdir(parents=True, exist_ok=True)
template = {"code": "en", "name": "English", "strings": {k: k for k in keys}}
(folder / "en.json").write_text(json.dumps(template, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"en.json: {len(keys)} texts")

for file in sorted(folder.glob("*.json")):
    if file.name == "en.json":
        continue
    strings = json.loads(file.read_text(encoding="utf-8"))["strings"]
    missing = [k for k in keys if k not in strings]
    unused = [k for k in strings if k not in keys]
    print(f"{file.name}: {len(missing)} missing, {len(unused)} unused")
    for k in missing:
        print("  missing:", k)
    for k in unused:
        print("  unused:", k)
