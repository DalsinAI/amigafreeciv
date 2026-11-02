/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 AmiCradle Team
 *
 * SelectTimeout: does bsdsocket.library's WaitSelect() keep its timeout?
 * Freeciv's SDL2 client calls select() with 10 ms on its server socket in
 * every pass of its event loop. Listens on 127.0.0.1:5601, connects to
 * itself, and times WaitSelect() on the idle connection with no timeout
 * (zero), 10 ms and 500 ms, then after one byte is sent.
 */
#include <stdio.h>                     /* libnix's: StdFileDes, _lx_fhfromfd */
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <proto/bsdsocket.h>

int fc_amiga_select(int n, fd_set *r, fd_set *w, fd_set *e, struct timeval *tv);

/* bsdsocket.library's number for a libnix descriptor */
static int bsd(int fd)
{
  StdFileDes *f = _lx_fhfromfd(fd);

  if (f == NULL || !(f->lx_flags & LX_SOCKET)) {
    printf("fd %d is not one of libnix's sockets (flags %d)\n", fd,
           f != NULL ? f->lx_flags : -1);
    return -1;
  }
  return f->lx_sock;
}

static long ms_since(const struct timeval *t0)
{
  struct timeval t;

  gettimeofday(&t, NULL);
  return (t.tv_sec - t0->tv_sec) * 1000 + (t.tv_usec - t0->tv_usec) / 1000;
}

static void probe(int s, long usec, const char *what)
{
  fd_set r;
  struct timeval tv, t0;
  LONG rc;

  FD_ZERO(&r);
  FD_SET(s, &r);
  tv.tv_sec = usec / 1000000;
  tv.tv_usec = usec % 1000000;
  gettimeofday(&t0, NULL);
  rc = WaitSelect(s + 1, &r, NULL, NULL, (APTR) &tv, NULL);
  printf("%-28s timeout %6ld us: rc %ld, readable %d, took %ld ms\n",
         what, usec, (long) rc, (int) FD_ISSET(s, &r), ms_since(&t0));
  fflush(stdout);
}

int main(void)
{
  struct sockaddr_in a;
  long ls, cs, as;
  socklen_t len = sizeof(a);

  /* stdout first, so libnix's standard descriptors are taken */
  printf("SelectTimeout\n");
  fflush(stdout);
  if (SocketBase == NULL) {
    printf("no bsdsocket.library\n");
    return 20;
  }
  ls = socket(AF_INET, SOCK_STREAM, 0);
  memset(&a, 0, sizeof(a));
  a.sin_family = AF_INET;
  a.sin_port = htons(5601);
  a.sin_addr.s_addr = inet_addr("127.0.0.1");
  if (bind(ls, (struct sockaddr *) &a, sizeof(a)) < 0 || listen(ls, 1) < 0) {
    printf("bind/listen failed\n");
    return 20;
  }
  cs = socket(AF_INET, SOCK_STREAM, 0);
  if (connect(cs, (struct sockaddr *) &a, sizeof(a)) < 0) {
    printf("connect failed\n");
    return 20;
  }
  as = accept(ls, (struct sockaddr *) &a, &len);
  printf("libnix fds: listen %ld, client %ld, accepted %ld; bsdsocket %d %d %d\n",
         ls, cs, as, bsd(ls), bsd(cs), bsd(as));
  if (bsd(cs) < 0 || bsd(as) < 0) {
    return 20;
  }
  probe(bsd(cs), 0, "WaitSelect idle");
  probe(bsd(cs), 10000, "WaitSelect idle");
  probe(bsd(cs), 500000, "WaitSelect idle");
  {
    fd_set r;
    struct timeval tv, t0;
    int rc;

    FD_ZERO(&r);
    FD_SET(cs, &r);
    gettimeofday(&t0, NULL);
    tv.tv_sec = 0;
    tv.tv_usec = 10000;
    rc = fc_amiga_select(cs + 1, &r, NULL, NULL, &tv);
    printf("fc_amiga_select idle, 10 ms: rc %d, took %ld ms\n", rc, ms_since(&t0));
  }
  send(as, "x", 1, 0);
  probe(bsd(cs), 500000, "WaitSelect after one byte");
  return 0;
}
