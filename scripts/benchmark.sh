#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/bench
xcrun clang -arch arm64 -fobjc-arc -fmodules -O2 -Wall -Wextra -Werror -mmacosx-version-min=15.0 -Icore bench/search.m core/SHSearchSnapshot.m core/sh_match.c -framework Foundation -o .build/bench/search
sw_vers
sysctl -n machdep.cpu.brand_string
.build/bench/search 10000
.build/bench/search 100000
xcrun clang -arch arm64 -fobjc-arc -fmodules -O2 -Wall -Wextra -Werror -mmacosx-version-min=15.0 -Icore bench/catalog.m core/SHCatalog.m core/SHScanner.m -framework Foundation -lsqlite3 -o .build/bench/catalog
.build/bench/catalog
xcrun clang -O2 -Wall -Wextra -Werror bench/process.c -o .build/bench/process
