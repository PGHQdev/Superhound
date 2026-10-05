#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tests
flags=(-fobjc-arc -fmodules -Wall -Wextra -Werror -g -O1 -mmacosx-version-min=15.0 -Icore -Iapp -fsanitize=address,undefined)
xcrun clang "${flags[@]}" tests/search.m core/SHSearchSnapshot.m core/SHQueryController.m core/SHUsage.m core/sh_match.c -framework Foundation -o .build/tests/search
.build/tests/search
xcrun clang "${flags[@]}" tests/answer.m core/SHAnswer.m -framework Foundation -o .build/tests/answer
.build/tests/answer
xcrun clang "${flags[@]}" tests/emoji.m core/SHEmoji.m core/SHSearchSnapshot.m core/sh_match.c -framework Foundation -framework CoreText -o .build/tests/emoji
.build/tests/emoji app/emoji.tsv
if [[ -f tests/catalog.m ]]; then
 xcrun clang "${flags[@]}" tests/catalog.m core/SHCatalog.m core/SHScanner.m app/SHFolderAccess.m -framework Foundation -lsqlite3 -o .build/tests/catalog
 .build/tests/catalog
fi

xcrun clang "${flags[@]}" tests/library.m core/*.m core/sh_match.c app/SHFolderAccess.m -framework Foundation -framework CoreServices -lsqlite3 -o .build/tests/library
.build/tests/library > .build/tests/library.log 2>&1 || { cat .build/tests/library.log; exit 1; }
tail -1 .build/tests/library.log

xcrun clang "${flags[@]}" tests/snapshot-equivalence.m core/SHSearchSnapshot.m core/sh_match.c -framework Foundation -o .build/tests/snapshot-equivalence
.build/tests/snapshot-equivalence > .build/tests/snapshot-equivalence.txt
cmp tests/snapshot-equivalence.expected .build/tests/snapshot-equivalence.txt
echo 'PASS snapshot regression: 40 mixed-query/root-mask result sets match the recorded ranking'
