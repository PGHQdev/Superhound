#ifndef SH_MATCH_H
#define SH_MATCH_H
#include <stdint.h>
#include <stddef.h>
// All positions and lengths are Unicode scalar values, never UTF-8 bytes.
typedef struct { const uint32_t *points; const uint8_t *boundaries; size_t length; } SHText;
typedef struct { unsigned rank; size_t compactness; } SHMatch; // 0 exact, 1 prefix, 2 word initials or start of a later word, 3 substring, 9 absent
SHMatch sh_match(SHText text, SHText term);
// Typing-error match: the term is 1 edit (2 for 8+ characters) from the start of a word in text.
// An edit is a wrong, missing, extra, or swapped character. Rank 5 = 1 edit, 6 = 2 edits, 9 absent.
SHMatch sh_match_typo(SHText text, SHText term);
#endif
