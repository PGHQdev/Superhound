#!/usr/bin/env python3
"""Writes app/en.lproj from the code, or checks it and the other app/<locale>.lproj folders.

python3 -I scripts/strings.py          writes app/en.lproj/Localizable.strings and InfoPlist.strings
python3 -I scripts/strings.py --check  fails when app/en.lproj is out of date, or a locale has a missing key,
                                       an extra key, other format specifiers, or a file that does not parse
"""
import collections, json, re, subprocess, sys
from pathlib import Path
from xml.sax.saxutils import unescape

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'app'
EN = APP / 'en.lproj'
SOURCES = sorted(APP.glob('*.m')) + sorted((ROOT / 'core').glob('*.m'))
TABLES = ('Localizable.strings', 'InfoPlist.strings')
# Comments for the Info.plist keys that macOS shows to the user.
INFO_COMMENTS = {'NSAppleEventsUsageDescription': 'Privacy text that macOS shows when Superhound asks to control Finder, System Events, or the login window'}
ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', "'": "'", '\\': '\\', 'e': '\x1b', '0': '\0', 'a': '\a', 'b': '\b', 'f': '\f', 'v': '\v', '?': '?'}
SPEC = re.compile(r"%(?:(\d+)\$)?[-+ #0']*(?:\d+|\*)?(\.(?:\d+|\*))?(hh|h|ll|l|q|L|z|t|j)?([@dDiuUxXoOfFeEgGcCsSpaA%])")


class Failure(Exception):
    pass


def line_of(text, index):
    return text.count('\n', 0, index) + 1


def read_literal(text, i, where):
    """Reads one C string literal that starts at text[i] == '"'; returns the decoded value and the index after it."""
    out, i = [], i + 1
    while i < len(text):
        c = text[i]
        if c == '"':
            return ''.join(out), i + 1
        if c == '\n':
            break
        if c == '\\':
            e = text[i + 1]
            if e in ESCAPES:
                out.append(ESCAPES[e]); i += 2; continue
            if e in 'uU':
                size = 4 if e == 'u' else 8
                out.append(chr(int(text[i + 2:i + 2 + size], 16))); i += 2 + size; continue
            if e == 'x':
                m = re.match(r'[0-9A-Fa-f]+', text[i + 2:])
                out.append(chr(int(m.group(0), 16))); i += 2 + len(m.group(0)); continue
            raise Failure(f'{where}: unknown escape \\{e} in a string')
        out.append(c); i += 1
    raise Failure(f'{where}: a string literal does not end')


def skip_space(text, i):
    while i < len(text):
        if text[i].isspace():
            i += 1
        elif text.startswith('//', i):
            i = text.find('\n', i); i = len(text) if i < 0 else i
        elif text.startswith('/*', i):
            i = text.index('*/', i) + 2
        else:
            break
    return i


def read_strings(text, i, where):
    """Reads @"a" or adjacent literals @"a" "b"; returns the joined value and the next index, or None when no literal is there."""
    parts = []
    while True:
        j = skip_space(text, i)
        if text.startswith('@"', j):
            j += 1
        elif not (parts and text.startswith('"', j)):
            break
        value, i = read_literal(text, j, where)
        parts.append(value)
    return (''.join(parts), i) if parts else (None, i)


def scan():
    """Returns {key: set of comments} from every NSLocalizedString call in the sources."""
    found = collections.OrderedDict()
    for path in SOURCES:
        text, i, rel = path.read_text(encoding='utf-8'), 0, path.relative_to(ROOT)
        while i < len(text):
            if text.startswith('//', i):
                i = text.find('\n', i); i = len(text) if i < 0 else i
            elif text.startswith('/*', i):
                i = text.index('*/', i) + 2
            elif text[i] == '"':
                i = read_literal(text, i, f'{rel}:{line_of(text, i)}')[1]
            elif text[i] == "'":
                i = text.index("'", i + (3 if text[i + 1] == '\\' else 1)) + 1
            elif text.startswith('NSLocalizedString', i) and not (i and (text[i - 1].isalnum() or text[i - 1] == '_')):
                where = f'{rel}:{line_of(text, i)}'
                j = skip_space(text, i + len('NSLocalizedString'))
                if not text.startswith('(', j):
                    raise Failure(f'{where}: NSLocalizedString without arguments')
                key, j = read_strings(text, j + 1, where)
                j = skip_space(text, j)
                if key is None or not text.startswith(',', j):
                    raise Failure(f'{where}: the key of NSLocalizedString must be one @"..." literal')
                comment, j = read_strings(text, j + 1, where)
                j = skip_space(text, j)
                if comment is None:
                    if not text.startswith('nil', j):
                        raise Failure(f'{where}: the comment of NSLocalizedString must be @"..." or nil')
                    j = skip_space(text, j + 3)
                if not text.startswith(')', j):
                    raise Failure(f'{where}: NSLocalizedString takes two arguments')
                if not key:
                    raise Failure(f'{where}: empty NSLocalizedString key')
                if comment and '*/' in comment:
                    raise Failure(f'{where}: a comment must not contain */')
                found.setdefault(key, set())
                if comment:
                    found[key].add(comment)
                i = j + 1
            else:
                i += 1
    return found


def info_strings():
    """Returns {key: text} for the NS*UsageDescription keys that scripts/build.sh writes to Info.plist."""
    text = (ROOT / 'scripts' / 'build.sh').read_text(encoding='utf-8')
    pairs = re.findall(r'<key>(NS\w*UsageDescription)</key>\s*<string>(.*?)</string>', text, re.S)
    if not pairs:
        raise Failure('scripts/build.sh: no NS*UsageDescription key found')
    return {k: unescape(v, {'&quot;': '"', '&apos;': "'"}) for k, v in pairs}


def quote(value):
    out = []
    for c in value:
        if c in '"\\':
            out.append('\\' + c)
        elif c == '\n':
            out.append('\\n')
        elif c == '\t':
            out.append('\\t')
        elif ord(c) < 32:
            out.append('\\U%04x' % ord(c))
        else:
            out.append(c)
    return '"' + ''.join(out) + '"'


def render(entries):
    """entries: [(key, value, [comments])] -> .strings text, sorted by key."""
    blocks = []
    for key, value, comments in sorted(entries, key=lambda e: e[0]):
        note = '\n   '.join(sorted(comments)) if comments else 'No comment'
        blocks.append(f'/* {note} */\n{quote(key)} = {quote(value)};\n')
    return '\n'.join(blocks)


def expected():
    """Returns {file name: (text, number of keys)} for app/en.lproj."""
    found, info = scan(), info_strings()
    return {
        'Localizable.strings': (render([(k, k, c) for k, c in found.items()]), len(found)),
        'InfoPlist.strings': (render([(k, v, [INFO_COMMENTS.get(k, 'Privacy text that macOS shows')]) for k, v in info.items()]), len(info)),
    }


def parse(path):
    """Returns the table of a .strings file as a dict, through plutil, or raises Failure."""
    rel = path.relative_to(ROOT)
    run = subprocess.run(['/usr/bin/plutil', '-convert', 'json', '-o', '-', '--', str(path)], capture_output=True, text=True)
    if run.returncode:
        raise Failure(f'{rel} does not parse: {(run.stderr or run.stdout).strip()}')
    table = json.loads(run.stdout)
    if not isinstance(table, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in table.items()):
        raise Failure(f'{rel} is not a table of strings')
    return table


def specifiers(text):
    """The multiset of conversion types: %1$@ counts as %@, and %% is no specifier."""
    return collections.Counter((m.group(2) or '') + (m.group(3) or '') + m.group(4) for m in SPEC.finditer(text) if m.group(4) != '%')


def show(counter):
    return ' '.join(sorted('%' + t for t in counter.elements())) or 'none'


def check():
    problems = []
    for name, (text, _) in expected().items():
        path = EN / name
        if not path.exists() or path.read_text(encoding='utf-8') != text:
            problems.append(f'{path.relative_to(ROOT)} is out of date with the code. Run: python3 -I scripts/strings.py')
    english = {}
    for name in TABLES:
        try:
            english[name] = parse(EN / name) if (EN / name).exists() else {}
        except Failure as e:
            problems.append(str(e))
            english[name] = {}
    for folder in sorted(APP.glob('*.lproj')):
        if folder.name == 'en.lproj':
            continue
        for name in TABLES:
            path, rel = folder / name, (folder / name).relative_to(ROOT)
            if not path.exists():
                problems.append(f'{rel} is missing')
                continue
            try:
                table = parse(path)
            except Failure as e:
                problems.append(str(e))
                continue
            base = english[name]
            for key in sorted(base.keys() - table.keys()):
                problems.append(f'{rel}: missing key {quote(key)}')
            for key in sorted(table.keys() - base.keys()):
                problems.append(f'{rel}: extra key {quote(key)}')
            for key in sorted(base.keys() & table.keys()):
                want, got = specifiers(base[key]), specifiers(table[key])
                if want != got:
                    problems.append(f'{rel}: {quote(key)} has format specifiers {show(got)}; the English text has {show(want)}')
    if problems:
        print('\n'.join(problems), file=sys.stderr)
        print(f'FAIL strings: {len(problems)} problem(s)', file=sys.stderr)
        return 1
    locales = [f.name for f in sorted(APP.glob('*.lproj')) if f.name != 'en.lproj']
    print(f'PASS strings: app/en.lproj matches the code ({len(english["Localizable.strings"])} + {len(english["InfoPlist.strings"])} keys); locales checked: {", ".join(locales) or "none yet"}')
    return 0


def write():
    EN.mkdir(exist_ok=True)
    tables = expected()
    for name, (text, _) in tables.items():
        (EN / name).write_text(text, encoding='utf-8')
        run = subprocess.run(['/usr/bin/plutil', '-lint', '--', str(EN / name)], capture_output=True, text=True)
        if run.returncode:
            raise Failure(run.stdout.strip() or run.stderr.strip())
    print(f'Wrote app/en.lproj: Localizable.strings ({tables["Localizable.strings"][1]} keys), InfoPlist.strings ({tables["InfoPlist.strings"][1]} keys)')
    return 0


def main(argv):
    if argv not in ([], ['--check']):
        print('Usage: python3 -I scripts/strings.py [--check]', file=sys.stderr)
        return 2
    try:
        return check() if argv else write()
    except Failure as e:
        print(f'FAIL strings: {e}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
