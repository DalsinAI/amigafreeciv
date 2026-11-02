/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (c) 2026 AmiCradle Team
 *
 * The ICU subset Freeciv needs (unicode/ustring.h here), without ICU.
 *
 * Differences from ICU, on purpose:
 * - a byte that does not start or continue valid UTF-8 is read as the
 *   Latin-1 character of that value (AmigaOS file and volume names are
 *   Latin-1) instead of failing the conversion;
 * - case folding is simple one-to-one folding of ASCII, Latin-1, Latin
 *   Extended-A, Greek and Cyrillic.
 */
#include <stddef.h>

#include "unicode/ustring.h"

/* Decode one character from UTF-8. *len gets the bytes used. */
static uint32_t utf8_next(const unsigned char *s, int32_t left, int32_t *len)
{
  unsigned char c = s[0];
  int32_t need, i;
  uint32_t cp, min;

  if (c < 0x80) {
    *len = 1;
    return c;
  } else if (c >= 0xC2 && c <= 0xDF) {
    need = 1; cp = c & 0x1F; min = 0x80;
  } else if (c >= 0xE0 && c <= 0xEF) {
    need = 2; cp = c & 0x0F; min = 0x800;
  } else if (c >= 0xF0 && c <= 0xF4) {
    need = 3; cp = c & 0x07; min = 0x10000;
  } else {
    *len = 1;
    return c;                   /* Latin-1 */
  }
  if (left >= 0 && left < need + 1) {
    *len = 1;
    return c;
  }
  for (i = 1; i <= need; i++) {
    if ((s[i] & 0xC0) != 0x80) {
      *len = 1;
      return c;
    }
    cp = (cp << 6) | (s[i] & 0x3F);
  }
  if (cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) {
    *len = 1;
    return c;
  }
  *len = need + 1;
  return cp;
}

static void finish(int32_t length, int32_t capacity, int32_t *pDestLength,
                   UErrorCode *pErrorCode)
{
  if (pDestLength != NULL) {
    *pDestLength = length;
  }
  if (length > capacity) {
    *pErrorCode = U_BUFFER_OVERFLOW_ERROR;
  } else if (length == capacity) {
    *pErrorCode = U_STRING_NOT_TERMINATED_WARNING;
  }
}

UChar *u_strFromUTF8(UChar *dest, int32_t destCapacity, int32_t *pDestLength,
                     const char *src, int32_t srcLength,
                     UErrorCode *pErrorCode)
{
  const unsigned char *s = (const unsigned char *) src;
  int32_t pos = 0, out = 0;

  if (pErrorCode == NULL || U_FAILURE(*pErrorCode)) {
    return NULL;
  }
  if (src == NULL || destCapacity < 0 || (dest == NULL && destCapacity > 0)) {
    *pErrorCode = U_ILLEGAL_ARGUMENT_ERROR;
    return NULL;
  }
  while (srcLength < 0 ? s[pos] != '\0' : pos < srcLength) {
    int32_t len;
    uint32_t cp = utf8_next(s + pos,
                            srcLength < 0 ? -1 : srcLength - pos, &len);

    pos += len;
    if (cp >= 0x10000) {
      cp -= 0x10000;
      if (out + 1 < destCapacity) {
        dest[out] = (UChar) (0xD800 + (cp >> 10));
        dest[out + 1] = (UChar) (0xDC00 + (cp & 0x3FF));
      }
      out += 2;
    } else {
      if (out < destCapacity) {
        dest[out] = (UChar) cp;
      }
      out++;
    }
  }
  if (out < destCapacity) {
    dest[out] = 0;
  }
  finish(out, destCapacity, pDestLength, pErrorCode);
  return dest;
}

UChar *u_strFromUTF8Lenient(UChar *dest, int32_t destCapacity,
                            int32_t *pDestLength, const char *src,
                            int32_t srcLength, UErrorCode *pErrorCode)
{
  return u_strFromUTF8(dest, destCapacity, pDestLength, src, srcLength,
                       pErrorCode);
}

char *u_strToUTF8(char *dest, int32_t destCapacity, int32_t *pDestLength,
                  const UChar *src, int32_t srcLength,
                  UErrorCode *pErrorCode)
{
  int32_t pos = 0, out = 0;
  int32_t written = 0;
  int full = 0;                 /* stop writing once a character didn't fit */

  if (pErrorCode == NULL || U_FAILURE(*pErrorCode)) {
    return NULL;
  }
  if (src == NULL || destCapacity < 0 || (dest == NULL && destCapacity > 0)) {
    *pErrorCode = U_ILLEGAL_ARGUMENT_ERROR;
    return NULL;
  }
  while (srcLength < 0 ? src[pos] != 0 : pos < srcLength) {
    uint32_t cp = src[pos++];
    unsigned char b[4];
    int32_t n, i;

    if (cp >= 0xD800 && cp <= 0xDBFF
        && (srcLength < 0 ? src[pos] != 0 : pos < srcLength)
        && src[pos] >= 0xDC00 && src[pos] <= 0xDFFF) {
      cp = 0x10000 + ((cp - 0xD800) << 10) + (src[pos++] - 0xDC00);
    } else if (cp >= 0xD800 && cp <= 0xDFFF) {
      cp = 0xFFFD;
    }
    if (cp < 0x80) {
      b[0] = (unsigned char) cp; n = 1;
    } else if (cp < 0x800) {
      b[0] = 0xC0 | (cp >> 6); b[1] = 0x80 | (cp & 0x3F); n = 2;
    } else if (cp < 0x10000) {
      b[0] = 0xE0 | (cp >> 12); b[1] = 0x80 | ((cp >> 6) & 0x3F);
      b[2] = 0x80 | (cp & 0x3F); n = 3;
    } else {
      b[0] = 0xF0 | (cp >> 18); b[1] = 0x80 | ((cp >> 12) & 0x3F);
      b[2] = 0x80 | ((cp >> 6) & 0x3F); b[3] = 0x80 | (cp & 0x3F); n = 4;
    }
    if (!full && out + n <= destCapacity) {
      for (i = 0; i < n; i++) {
        dest[out + i] = (char) b[i];
      }
      written = out + n;
    } else {
      full = 1;
    }
    out += n;
  }
  if (written < destCapacity) {
    /* ICU leaves the rest undefined; a cut string ends where it was cut */
    dest[written] = '\0';
  }
  finish(out, destCapacity, pDestLength, pErrorCode);
  return dest;
}

static UChar fold(UChar c)
{
  if (c < 0x80) {
    return (c >= 'A' && c <= 'Z') ? c + 32 : c;
  }
  if (c < 0x100) {
    return (c >= 0xC0 && c <= 0xDE && c != 0xD7) ? c + 32 : c;
  }
  if (c < 0x180) {
    if (c == 0x130) return 0x69;
    if (c == 0x178) return 0xFF;
    if (c == 0x17F) return 0x73;
    if ((c <= 0x12F || (c >= 0x132 && c <= 0x137)
         || (c >= 0x14A && c <= 0x177)) && !(c & 1)) {
      return c + 1;
    }
    if (((c >= 0x139 && c <= 0x148) || (c >= 0x179 && c <= 0x17E))
        && (c & 1)) {
      return c + 1;
    }
    return c;
  }
  if (c >= 0x386 && c <= 0x3AB) {
    if (c >= 0x391 && c <= 0x3AB && c != 0x3A2) return c + 32;
    if (c == 0x386) return 0x3AC;
    if (c >= 0x388 && c <= 0x38A) return c + 37;
    if (c == 0x38C) return 0x3CC;
    if (c == 0x38E || c == 0x38F) return c + 63;
    return c;
  }
  if (c == 0x3C2) {
    return 0x3C3;
  }
  if (c >= 0x400 && c <= 0x4BF) {
    if (c <= 0x40F) return c + 80;
    if (c <= 0x42F) return c + 32;
    if (((c >= 0x460 && c <= 0x481) || c >= 0x48A) && !(c & 1)) return c + 1;
  }
  return c;
}

int32_t u_strCaseCompare(const UChar *s1, int32_t length1,
                         const UChar *s2, int32_t length2,
                         uint32_t options, UErrorCode *pErrorCode)
{
  int32_t i = 0;

  (void) options;
  if (pErrorCode == NULL || U_FAILURE(*pErrorCode)) {
    return 0;
  }
  for (;;) {
    int end1 = length1 < 0 ? s1[i] == 0 : i >= length1;
    int end2 = length2 < 0 ? s2[i] == 0 : i >= length2;
    UChar c1, c2;

    if (end1 || end2) {
      return end1 && end2 ? 0 : (end1 ? -1 : 1);
    }
    c1 = fold(s1[i]);
    c2 = fold(s2[i]);
    if (c1 != c2) {
      return (int32_t) c1 - (int32_t) c2;
    }
    i++;
  }
}
