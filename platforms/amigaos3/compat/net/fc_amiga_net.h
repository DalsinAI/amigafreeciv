/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 AmiCradle Team
 *
 * Freeciv's sockets on AmigaOS 3.x straight on bsdsocket.library
 * (fc_amiga_net.c; utility/netintf.h includes this, patches/0013).
 *
 * libnix keeps its sockets in the same descriptor table as its files and
 * hands a new socket any slot whose use count is 0, the standard streams'
 * slots included: in the lab the client's server socket was descriptor 0,
 * 1 or 2, and its reads, writes and select() went to the wrong thing. Here
 * a socket's number is bsdsocket.library's own, from the port's own
 * library base, and libnix's descriptor table never sees it. Only call
 * these with sockets; files keep libnix's read(), write() and close().
 */
#ifndef FC_AMIGA_NET_H
#define FC_AMIGA_NET_H

#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/select.h>

int fc_amiga_net_init(void);
int fc_amiga_socket(int domain, int type, int protocol);
int fc_amiga_bind(int s, const struct sockaddr *a, socklen_t len);
int fc_amiga_listen(int s, int backlog);
int fc_amiga_accept(int s, struct sockaddr *a, socklen_t *len);
int fc_amiga_connect(int s, const struct sockaddr *a, socklen_t len);
int fc_amiga_setsockopt(int s, int level, int name, const void *val,
                        socklen_t len);
int fc_amiga_getsockopt(int s, int level, int name, void *val,
                        socklen_t *len);
int fc_amiga_getsockname(int s, struct sockaddr *a, socklen_t *len);
int fc_amiga_getpeername(int s, struct sockaddr *a, socklen_t *len);
ssize_t fc_amiga_recv(int s, void *buf, size_t len, int flags);
ssize_t fc_amiga_send(int s, const void *buf, size_t len, int flags);
ssize_t fc_amiga_recvfrom(int s, void *buf, size_t len, int flags,
                          struct sockaddr *a, socklen_t *alen);
ssize_t fc_amiga_sendto(int s, const void *buf, size_t len, int flags,
                        const struct sockaddr *a, socklen_t alen);
int fc_amiga_closesocket(int s);
int fc_amiga_nonblock(int s);
int fc_amiga_select(int n, fd_set *r, fd_set *w, fd_set *e,
                    struct timeval *tv);

#ifndef FC_AMIGA_NET_NO_MACROS
#define socket(d, t, p)               fc_amiga_socket(d, t, p)
#define bind(s, a, l)                 fc_amiga_bind(s, a, l)
#define listen(s, b)                  fc_amiga_listen(s, b)
#define accept(s, a, l)               fc_amiga_accept(s, a, l)
#define connect(s, a, l)              fc_amiga_connect(s, a, l)
#define setsockopt(s, l, n, v, vl)    fc_amiga_setsockopt(s, l, n, v, vl)
#define getsockopt(s, l, n, v, vl)    fc_amiga_getsockopt(s, l, n, v, vl)
#define getsockname(s, a, l)          fc_amiga_getsockname(s, a, l)
#define getpeername(s, a, l)          fc_amiga_getpeername(s, a, l)
#define recv(s, b, l, f)              fc_amiga_recv(s, b, l, f)
#define send(s, b, l, f)              fc_amiga_send(s, b, l, f)
#define recvfrom(s, b, l, f, a, al)   fc_amiga_recvfrom(s, b, l, f, a, al)
#define sendto(s, b, l, f, a, al)     fc_amiga_sendto(s, b, l, f, a, al)
#endif /* FC_AMIGA_NET_NO_MACROS */

#endif /* FC_AMIGA_NET_H */
