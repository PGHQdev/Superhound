#!/usr/bin/env python3
"""Rebuild app/emoji.tsv from the Unicode emoji list and the CLDR English annotations.
Each line: emoji, name, keywords separated by "|". Skin tone variants are left out."""
import json, pathlib, urllib.request
LIST = "https://unicode.org/Public/emoji/latest/emoji-test.txt"
CLDR = "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-%s/%s/en/annotations.json"
def get(url): return urllib.request.urlopen(url, timeout=60).read().decode("utf-8")
notes = {}
for package, key in (("derived-full", "annotationsDerived"), ("full", "annotations")):
    notes.update(json.loads(get(CLDR % (package, key)))[key]["annotations"])
bare = {k.replace("️", ""): v for k, v in notes.items()}
rows = []
for line in get(LIST).splitlines():
    if "; fully-qualified" not in line: continue
    points = [int(p, 16) for p in line.split(";")[0].split()]
    if any(0x1F3FB <= p <= 0x1F3FF for p in points): continue
    emoji = "".join(map(chr, points))
    note = notes.get(emoji) or bare.get(emoji.replace("️", "")) or {}
    name = (note.get("tts") or [line.split("#")[1].split(" ", 3)[3]])[0]
    words = [w for w in note.get("default", []) if w != name]
    rows.append("\t".join((emoji, name, "|".join(words))))
pathlib.Path(__file__).resolve().parent.parent.joinpath("app/emoji.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
print(len(rows), "emoji")
