/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 AmiCradle Team
 *
 * SelectTimeout: Freeciv's socket layer (compat/net) on a loopback
 * connection, as the client and its server use it. Listens on
 * 127.0.0.1:5601, connects to itself and checks that:
 *  - the standard streams still work after the sockets exist (libnix gave
 *    sockets the standard streams' descriptors, patches/0013);
 *  - select() keeps its timeouts on an idle connection (0, 10, 500 ms);
 *  - one byte sent is seen by select() and read back;
 *  - a non-blocking read with nothing waiting fails with EAGAIN;
 *  - the sockets close.
 * Prints PASS or FAIL for each and returns 0 only if all pass.
 */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fc_amiga_net.h>

static int failures;

static void check(int ok, const char *what)
{
  printf("%s %s\n", ok ? "PASS" : "FAIL", what);
  fflush(stdout);
  if (!ok) {
    failures++;
  }
}

static long ms_since(const struct timeval *t0)
{
  struct timeval t;

  gettimeofday(&t, NULL);
  return (t.tv_sec - t0->tv_sec) * 1000 + (t.tv_usec - t0->tv_usec) / 1000;
}

/* select() for reading on s with a timeout; the result, its time in ms */
static int wait_read(int s, long usec, long *took)
{
  fd_set r;
  struct timeval tv, t0;
  int rc;

  FD_ZERO(&r);
  FD_SET(s, &r);
  tv.tv_sec = usec / 1000000;
  tv.tv_usec = usec % 1000000;
  gettimeofday(&t0, NULL);
  rc = fc_amiga_select(s + 1, &r, NULL, NULL, &tv);
  *took = ms_since(&t0);
  printf("     select %6ld us: rc %d, readable %d, took %ld ms\n",
         usec, rc, rc > 0 && FD_ISSET(s, &r), *took);
  return rc > 0 && FD_ISSET(s, &r);
}

int main(void)
{
  struct sockaddr_in a;
  int ls, cs, as;
  socklen_t len = sizeof(a);
  long took;
  char c = 0;

  printf("SelectTimeout\n");
  fflush(stdout);
  if (fc_amiga_net_init() != 0) {
    printf("FAIL no bsdsocket.library\n");
    return 20;
  }
  ls = socket(AF_INET, SOCK_STREAM, 0);
  memset(&a, 0, sizeof(a));
  a.sin_family = AF_INET;
  a.sin_port = htons(5601);
  a.sin_addr.s_addr = inet_addr("127.0.0.1");
  check(ls >= 0 && bind(ls, (struct sockaddr *) &a, sizeof(a)) == 0
        && listen(ls, 1) == 0, "listen on 127.0.0.1:5601");
  cs = socket(AF_INET, SOCK_STREAM, 0);
  check(cs >= 0 && connect(cs, (struct sockaddr *) &a, sizeof(a)) == 0,
        "connect");
  as = accept(ls, (struct sockaddr *) &a, &len);
  check(as >= 0, "accept");
  if (failures) {
    return 20;
  }
  printf("     bsdsocket.library numbers: listen %d, client %d, accepted %d\n",
         ls, cs, as);
  fprintf(stderr, "     stderr after the sockets\n");
  check(printf("     stdout after the sockets\n") > 0 && fflush(stdout) == 0,
        "standard streams still work");

  check(!wait_read(cs, 0, &took) && took < 50, "idle, 0 ms: not readable");
  check(!wait_read(cs, 10000, &took) && took < 200, "idle, 10 ms: not readable, returns");
  check(!wait_read(cs, 500000, &took) && took >= 400 && took < 1500,
        "idle, 500 ms: waits about 500 ms");
  check(send(as, "x", 1, 0) == 1, "send one byte");
  check(wait_read(cs, 500000, &took) && took < 400, "readable after one byte");
  check(recv(cs, &c, 1, 0) == 1 && c == 'x', "read it back");
  check(fc_amiga_nonblock(cs) == 0, "non-blocking");
  errno = 0;
  check(recv(cs, &c, 1, 0) == -1 && (errno == EAGAIN || errno == EWOULDBLOCK),
        "non-blocking read with nothing waiting: EAGAIN");
  check(fc_amiga_closesocket(as) == 0 && fc_amiga_closesocket(cs) == 0
        && fc_amiga_closesocket(ls) == 0, "close");
  printf("%s\n", failures ? "SelectTimeout: FAILED" : "SelectTimeout: all passed");
  return failures ? 20 : 0;
}
