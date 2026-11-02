/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (c) 2026 AmiCradle Team
 *
 * RegistryLoad: loads one Freeciv ruleset file (with its *include files)
 * the way the server does, and reports each included file with the free
 * memory after it, so a ruleset that will not load can be looked at alone.
 *
 *   RegistryLoad classic/nations.ruleset
 */
#include <fc_config.h>

#include <stdio.h>
#ifdef __amigaos__
#include <proto/exec.h>
#endif

#include "fcintl.h"
#include "log.h"
#include "registry.h"
#include "shared.h"
#include "support.h"

static int files;

/* Linked with -Wl,--wrap=fileinfoname: every file the registry looks up,
 * *include files among them, passes here. */
const char *__real_fileinfoname(const struct strvec *dirs, const char *filename);
const char *__wrap_fileinfoname(const struct strvec *dirs, const char *filename);

const char *__wrap_fileinfoname(const struct strvec *dirs, const char *filename)
{
  const char *full = __real_fileinfoname(dirs, filename);

#ifdef __amigaos__
  printf("%4d %s, %lu bytes free\n", ++files, filename,
         (unsigned long) AvailMem(MEMF_ANY));
#else
  printf("%4d %s\n", ++files, filename);
#endif
  fflush(stdout);
  return full;
}

int main(int argc, char **argv)
{
  struct section_file *file;
  const char *full;

  if (argc != 2) {
    fprintf(stderr, "Usage: RegistryLoad RULESETFILE\n");
    return 20;
  }
  log_init(nullptr, LOG_VERBOSE, nullptr, nullptr, -1);
  fc_support_init();
  full = __real_fileinfoname(get_data_dirs(), argv[1]);
  if (full == nullptr) {
    fprintf(stderr, "RegistryLoad: %s not in the data path\n", argv[1]);
    return 20;
  }
  file = secfile_load(full, FALSE);
  if (file == nullptr) {
    printf("failed: %s\n", secfile_error());
    return 10;
  }
  printf("loaded %s: %d files included\n", argv[1], files);
  secfile_destroy(file);
  return 0;
}
