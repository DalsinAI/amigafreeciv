/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 AmiCradle Team
 *
 * select() for Freeciv's sockets on AmigaOS 3.x (utility/netintf.c's
 * fc_select() calls it; patches/0006).
 *
 * libnix's select() for its sockets passes bsdsocket.library's WaitSelect()
 * the highest socket's own number as nfds, not one more, so WaitSelect
 * never looks at it and a select() never finds data; with a timeout it
 * sends a timer request it never opened timer.device for (#80000004).
 * GFOpenRTG's SDL2_net works round the same libnix bug the same way
 * (library/modules/sdl2/satellites/net_shim.c, MIT). Until the compiler's
 * libnix is fixed, this asks WaitSelect() itself, through libnix's own
 * bsdsocket.library base, with the sockets' numbers and nfds one past the
 * highest. A set that holds anything but sockets goes to libnix's select().
 */
#include <errno.h>
#include <stdio.h>              /* libnix's: StdFileDes, _lx_fhfromfd, LX_SOCKET */
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <proto/bsdsocket.h>    /* SocketBase: libnix's, opened by its socket startup */

int fc_amiga_select(int n, fd_set *r, fd_set *w, fd_set *e, struct timeval *tv);

int fc_amiga_select(int n, fd_set *r, fd_set *w, fd_set *e, struct timeval *tv)
{
  fd_set sr, sw, se;
  int fd, top = 0, count = 0;
  LONG rc;

  if (n > FD_SETSIZE) {
    n = FD_SETSIZE;
  }
  FD_ZERO(&sr);
  FD_ZERO(&sw);
  FD_ZERO(&se);
  for (fd = 0; fd < n; fd++) {
    int ir = r && FD_ISSET(fd, r), iw = w && FD_ISSET(fd, w), ie = e && FD_ISSET(fd, e);
    StdFileDes *f;

    if (!ir && !iw && !ie) {
      continue;
    }
    f = _lx_fhfromfd(fd);
    if (!f || !(f->lx_flags & LX_SOCKET) || !SocketBase
        || f->lx_sock < 0 || f->lx_sock >= FD_SETSIZE) {
      return select(n, r, w, e, tv);
    }
    if (ir) FD_SET(f->lx_sock, &sr);
    if (iw) FD_SET(f->lx_sock, &sw);
    if (ie) FD_SET(f->lx_sock, &se);
    if (f->lx_sock + 1 > top) {
      top = f->lx_sock + 1;
    }
  }
  if (SocketBase == NULL) {
    return select(n, r, w, e, tv);
  }
  rc = WaitSelect(top, r ? &sr : NULL, w ? &sw : NULL, e ? &se : NULL,
                  (APTR) tv, NULL);
  if (rc < 0) {
    errno = Errno();
    return -1;
  }
  /* Back to libnix's numbers, in the caller's sets */
  for (fd = 0; fd < n; fd++) {
    int ir = r && FD_ISSET(fd, r), iw = w && FD_ISSET(fd, w), ie = e && FD_ISSET(fd, e);
    StdFileDes *f;

    if (!ir && !iw && !ie) {
      continue;
    }
    f = _lx_fhfromfd(fd);
    if (ir) { if (FD_ISSET(f->lx_sock, &sr)) count++; else FD_CLR(fd, r); }
    if (iw) { if (FD_ISSET(f->lx_sock, &sw)) count++; else FD_CLR(fd, w); }
    if (ie) { if (FD_ISSET(f->lx_sock, &se)) count++; else FD_CLR(fd, e); }
  }
  return count;
}
