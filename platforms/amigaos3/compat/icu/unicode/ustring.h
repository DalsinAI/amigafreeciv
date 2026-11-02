/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (c) 2026 AmiCradle Team
 *
 * The four ICU string calls Freeciv's utility/support.c makes, for
 * AmigaOS 3.x, where the full ICU library and its data (tens of MiB) are
 * out of reach of a 68040 game. UTF-8 <-> UTF-16 conversion is complete;
 * case-insensitive comparison folds ASCII, Latin-1, Latin Extended-A,
 * Greek and Cyrillic (simple one-to-one folding), which covers the names
 * Freeciv's rulesets, nations and players use. It is not ICU: no full
 * case folding (no German sharp s to "ss"), no normalisation.
 */
#ifndef FC_AMIGA_ICU_USTRING_H
#define FC_AMIGA_ICU_USTRING_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint16_t UChar;
typedef int8_t UBool;

typedef enum UErrorCode {
  U_STRING_NOT_TERMINATED_WARNING = -124,
  U_ZERO_ERROR = 0,
  U_ILLEGAL_ARGUMENT_ERROR = 1,
  U_INVALID_CHAR_FOUND = 10,
  U_BUFFER_OVERFLOW_ERROR = 15
} UErrorCode;

#define U_SUCCESS(x) ((x) <= U_ZERO_ERROR)
#define U_FAILURE(x) ((x) > U_ZERO_ERROR)
#define U_COMPARE_CODE_POINT_ORDER 0x8000
#define U_FOLD_CASE_DEFAULT 0

UChar *u_strFromUTF8(UChar *dest, int32_t destCapacity, int32_t *pDestLength,
                     const char *src, int32_t srcLength,
                     UErrorCode *pErrorCode);
UChar *u_strFromUTF8Lenient(UChar *dest, int32_t destCapacity,
                            int32_t *pDestLength, const char *src,
                            int32_t srcLength, UErrorCode *pErrorCode);
char *u_strToUTF8(char *dest, int32_t destCapacity, int32_t *pDestLength,
                  const UChar *src, int32_t srcLength,
                  UErrorCode *pErrorCode);
int32_t u_strCaseCompare(const UChar *s1, int32_t length1,
                         const UChar *s2, int32_t length2,
                         uint32_t options, UErrorCode *pErrorCode);

#ifdef __cplusplus
}
#endif

#endif /* FC_AMIGA_ICU_USTRING_H */
