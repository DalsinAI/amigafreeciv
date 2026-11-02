/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 AmiCradle Team
 *
 * UnTar: unpacks an uncompressed ustar archive (FreecivData.tar) on
 * AmigaOS, so the Freeciv data drawer, hundreds of files, travels as one.
 * Directories and regular files only; names are taken as they are, below
 * the destination.
 *
 *   UnTar ARCHIVE [DESTINATION]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

static const char version[] __attribute__((used)) = "$VER: UnTar 1.0 (2.11.2026)";

static unsigned long octal(const char *p, int n)
{
  unsigned long v = 0;

  while (n-- > 0 && *p == ' ') {
    p++;
  }
  while (n-- >= 0 && *p >= '0' && *p <= '7') {
    v = v * 8 + (unsigned long) (*p++ - '0');
  }
  return v;
}

/* Make every directory on the way to path (path itself too if dir). */
static void make_dirs(char *path, int dir)
{
  char *p;

  for (p = path; *p; p++) {
    if (*p == '/' && p != path && p[-1] != ':') {
      *p = '\0';
      mkdir(path, 0755);
      *p = '/';
    }
  }
  if (dir) {
    mkdir(path, 0755);
  }
}

int main(int argc, char **argv)
{
  static char block[512], buf[32768];
  char name[512];
  FILE *in;
  unsigned long files = 0, bytes = 0;

  if (argc < 2 || argc > 3) {
    fprintf(stderr, "Usage: UnTar ARCHIVE [DESTINATION]\n");
    return 20;
  }
  in = fopen(argv[1], "rb");
  if (in == NULL) {
    fprintf(stderr, "UnTar: cannot open %s\n", argv[1]);
    return 20;
  }
  while (fread(block, 1, 512, in) == 512 && block[0] != '\0') {
    unsigned long size = octal(block + 124, 12);
    char type = block[156];
    const char *dest = argc == 3 ? argv[2] : "";
    size_t dl = strlen(dest);
    char entry[256 + 1 + 100 + 1];

    entry[0] = '\0';
    if (memcmp(block + 257, "ustar", 5) == 0 && block[345] != '\0') {
      snprintf(entry, sizeof(entry), "%.155s/%.100s", block + 345, block);
    } else {
      snprintf(entry, sizeof(entry), "%.100s", block);
    }
    if (strncmp(entry, "./", 2) == 0) {
      memmove(entry, entry + 2, strlen(entry + 2) + 1);
    }
    snprintf(name, sizeof(name), "%s%s%s", dest,
             dl == 0 || dest[dl - 1] == ':' || dest[dl - 1] == '/' ? "" : "/",
             entry);
    if (strstr(entry, "..") != NULL || entry[0] == '/') {
      fprintf(stderr, "UnTar: skipping %s\n", entry);
      type = 'x';
    }
    if (type == '5') {
      size_t l = strlen(name);

      if (l > 0 && name[l - 1] == '/') {
        name[l - 1] = '\0';
      }
      make_dirs(name, 1);
    } else if (type == '0' || type == '\0') {
      FILE *out;
      unsigned long left = size;

      make_dirs(name, 0);
      out = fopen(name, "wb");
      if (out == NULL) {
        fprintf(stderr, "UnTar: cannot write %s\n", name);
        fclose(in);
        return 20;
      }
      while (left > 0) {
        size_t want = left > sizeof(buf) ? sizeof(buf) : left;
        size_t got = fread(buf, 1, want, in);

        if (got != want || fwrite(buf, 1, got, out) != got) {
          fprintf(stderr, "UnTar: short read or write at %s\n", name);
          fclose(out);
          fclose(in);
          return 20;
        }
        left -= got;
      }
      fclose(out);
      fseek(in, (long) ((512 - size % 512) % 512), SEEK_CUR);
      files++;
      bytes += size;
      continue;
    }
    /* Anything else (links, pax headers): skip its data */
    fseek(in, (long) ((size + 511) / 512 * 512), SEEK_CUR);
  }
  fclose(in);
  printf("UnTar: %lu files, %lu bytes\n", files, bytes);
  return 0;
}
