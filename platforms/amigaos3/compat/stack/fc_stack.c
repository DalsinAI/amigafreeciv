/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 AmiCradle Team
 *
 * Freeciv's stack on AmigaOS 3.x: libnix's startup gives the program a stack
 * of this size when the Shell or Workbench gave it less (swapstack), so
 * freeciv-server started by the client, from Workbench or from a Shell with
 * the default 4 KB stack has room for the AI's path finding. build_sdk.sh
 * puts the object on every link (the Meson cross file).
 */
unsigned long __stack = 1024 * 1024;
