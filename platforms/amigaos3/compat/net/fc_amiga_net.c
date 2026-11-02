/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 AmiCradle Team
 *
 * Freeciv's sockets on AmigaOS 3.x straight on bsdsocket.library: see
 * fc_amiga_net.h. The port opens its own library base (fc_SocketBase),
 * not libnix's SocketBase, so libnix's descriptor table never holds one of
 * Freeciv's sockets, and closes it at exit, which closes any socket still
 * open (the server's listening socket among them). A failed call sets the
 * C library's errno from the library's Errno(): bsdsocket.library and
 * libnix both use the BSD numbers (EAGAIN 35, EINPROGRESS 36).
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/filio.h>
#include <proto/exec.h>

#define FC_AMIGA_NET_NO_MACROS
#include "fc_amiga_net.h"

#define __NOLIBBASE__
#define BSDSOCKET_BASE_NAME fc_SocketBase
#include <proto/bsdsocket.h>

struct Library *fc_SocketBase = NULL;

static void fc_amiga_net_close(void)
{
  if (fc_SocketBase != NULL) {
    CloseLibrary(fc_SocketBase);
    fc_SocketBase = NULL;
  }
}

/* 0 when bsdsocket.library is open, else -1 with errno set */
int fc_amiga_net_init(void)
{
  static int tried;

  if (fc_SocketBase != NULL) {
    return 0;
  }
  if (!tried) {
    tried = 1;
    fc_SocketBase = OpenLibrary((CONST_STRPTR) "bsdsocket.library", 4);
    if (fc_SocketBase != NULL) {
      atexit(fc_amiga_net_close);
    } else {
      fprintf(stderr, "Freeciv: bsdsocket.library 4 cannot be opened;"
              " is the TCP/IP stack running?\n");
    }
  }
  if (fc_SocketBase == NULL) {
    errno = ENETDOWN;
    return -1;
  }
  return 0;
}

#define NEED_BASE(fail)                        \
  do {                                         \
    if (fc_amiga_net_init() != 0) {            \
      return (fail);                           \
    }                                          \
  } while (0)

/* The library's result; on failure the library's error in errno */
static long done(long rc)
{
  if (rc < 0) {
    errno = Errno();
  }
  return rc;
}

int fc_amiga_socket(int domain, int type, int protocol)
{
  NEED_BASE(-1);
  return done(socket(domain, type, protocol));
}

int fc_amiga_bind(int s, const struct sockaddr *a, socklen_t len)
{
  NEED_BASE(-1);
  return done(bind(s, a, len));
}

int fc_amiga_listen(int s, int backlog)
{
  NEED_BASE(-1);
  return done(listen(s, backlog));
}

int fc_amiga_accept(int s, struct sockaddr *a, socklen_t *len)
{
  NEED_BASE(-1);
  return done(accept(s, a, len));
}

int fc_amiga_connect(int s, const struct sockaddr *a, socklen_t len)
{
  NEED_BASE(-1);
  return done(connect(s, a, len));
}

int fc_amiga_setsockopt(int s, int level, int name, const void *val,
                        socklen_t len)
{
  NEED_BASE(-1);
  return done(setsockopt(s, level, name, val, len));
}

int fc_amiga_getsockopt(int s, int level, int name, void *val,
                        socklen_t *len)
{
  NEED_BASE(-1);
  return done(getsockopt(s, level, name, val, len));
}

int fc_amiga_getsockname(int s, struct sockaddr *a, socklen_t *len)
{
  NEED_BASE(-1);
  return done(getsockname(s, a, len));
}

int fc_amiga_getpeername(int s, struct sockaddr *a, socklen_t *len)
{
  NEED_BASE(-1);
  return done(getpeername(s, a, len));
}

ssize_t fc_amiga_recv(int s, void *buf, size_t len, int flags)
{
  NEED_BASE(-1);
  return done(recv(s, buf, len, flags));
}

ssize_t fc_amiga_send(int s, const void *buf, size_t len, int flags)
{
  NEED_BASE(-1);
  return done(send(s, buf, len, flags));
}

ssize_t fc_amiga_recvfrom(int s, void *buf, size_t len, int flags,
                          struct sockaddr *a, socklen_t *alen)
{
  NEED_BASE(-1);
  return done(recvfrom(s, buf, len, flags, a, alen));
}

ssize_t fc_amiga_sendto(int s, const void *buf, size_t len, int flags,
                        const struct sockaddr *a, socklen_t alen)
{
  NEED_BASE(-1);
  return done(sendto(s, buf, len, flags, a, alen));
}

int fc_amiga_closesocket(int s)
{
  NEED_BASE(-1);
  return done(CloseSocket(s));
}

int fc_amiga_nonblock(int s)
{
  LONG on = 1;

  NEED_BASE(-1);
  return done(IoctlSocket(s, FIONBIO, (APTR) &on));
}

/* select() on the library's own socket numbers. With no sets it is a
 * plain timed wait, as select() is. WaitSelect() may write to the timeout,
 * so it gets a copy. */
int fc_amiga_select(int n, fd_set *r, fd_set *w, fd_set *e,
                    struct timeval *tv)
{
  struct timeval t;

  NEED_BASE(-1);
  if (tv != NULL) {
    t = *tv;
  }
  return done(WaitSelect(n, r, w, e, tv != NULL ? &t : NULL, NULL));
}
