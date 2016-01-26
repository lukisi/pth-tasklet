/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * libpth.vapi - Vala bindings for GNU Pth
 */

[CCode (cname="pth_spawnable", cheader_filename = "pth_addendum.h", has_target = false)]
public delegate void * Native.LibPth.Spawnable (void* user_data);

[CCode(cheader_filename = "pth.h",
       lower_case_cprefix = "pth_", cprefix = "PTH_")]
namespace Native.LibPth {

    [CCode (cname = "struct timeval")]
    public struct timeval {}

    [CCode (cname = "struct timespec")]
    public struct timespec {}

    [SimpleType]
    [CCode (cname = "struct timeval")]
    public struct time_t {}
    //typedef struct timeval pth_time_t;

    [CCode (cname = "struct pth_st")]
    public struct pth_st {}
    //typedef struct pth_st *pth_t;

    public const int PRIO_MAX;
    public const int PRIO_STD;
    public const int PRIO_MIN;

    public const int STATE_SCHEDULER;
    public const int STATE_NEW;
    public const int STATE_READY;
    public const int STATE_WAITING;
    public const int STATE_DEAD;

    [CCode (cname = "struct pth_attr_st")]
    public struct attr_st {}
    //typedef struct pth_attr_st *pth_attr_t;

    [CCode (cname = "PTH_ATTR_DEFAULT")]
    public attr_st *ATTR_DEFAULT;

    public const int ATTR_PRIO;
    public const int ATTR_NAME;
    public const int ATTR_JOINABLE;
    public const int ATTR_CANCEL_STATE;
    public const int ATTR_STACK_SIZE;
    public const int ATTR_STACK_ADDR;
    public const int ATTR_DISPATCHES;
    public const int ATTR_TIME_SPAWN;
    public const int ATTR_TIME_LAST;
    public const int ATTR_TIME_RAN;
    public const int ATTR_START_FUNC;
    public const int ATTR_START_ARG;
    public const int ATTR_STATE;
    public const int ATTR_EVENTS;
    public const int ATTR_BOUND;

    [CCode (cname = "struct pth_msgport_st")]
    public struct msgport_st {}
    //typedef struct pth_msgport_st *pth_msgport_t;

    [CCode (cname = "struct pth_message_st")]
    public struct message_st {}
    //typedef struct pth_message_st pth_message_t;

    public int init();
    public int kill();
    public long ctrl(ulong querytype, ...);
    public long version();

    public attr_st *attr_of(pth_st *thread);
    public attr_st *attr_new();
    public int attr_init(attr_st *attr);
    public int attr_set(attr_st *attr, int attrname, ...);
    public int attr_get(attr_st *attr, int attrname, ...);
    public int attr_destroy(attr_st *attr);

    public pth_st *spawn(attr_st *attr, Spawnable f, void *user_data);
    //public int once
    public pth_st *self();
    public int suspend(pth_st *thread);
    public int resume(pth_st *thread);
    [CCode (cname = "pth_yield")]
    public int pth_yield(pth_st *thread);
    public int nap(time_t t);
    //public int wait
    public int cancel(pth_st *thread);
    public void cancel_point();
    public int abort(pth_st *thread);
    public int raise(pth_st *thread, int i);
    public int join(pth_st *thread, void **retval);
    public void exit(void *exit_val);

    public int accept(int fd, Posix.SockAddr *addr, size_t *plen);
    public int connect(int fd, /*const*/ Posix.SockAddr *addr, size_t len);
    public ssize_t recv(int fd, void *buf, size_t buflen, int flags);
    public ssize_t send(int fd, /*const*/ void *buf, size_t buflen, int flags);
    public ssize_t recvfrom(int fd, void *buf, size_t buflen, int flags, Posix.SockAddr *addr, size_t *plen);
    public ssize_t sendto(int fd, /*const*/ void *buf, size_t buflen, int flags, /*const*/ Posix.SockAddr *addr, size_t len);

    public int system(string? command);

    public ssize_t read(int fd, void *buf, size_t nbytes);
    public ssize_t write(int fd, /*const*/ void *buf, size_t nbytes);

    public time_t time(long sec, long usec);
    public time_t timeout(long sec, long usec);

    public msgport_st *msgport_create(string? name);
    public void msgport_destroy(msgport_st *port);
    public msgport_st *msgport_find(string name);
    public int msgport_pending(msgport_st *port);
    public int msgport_put(msgport_st *port, message_st *msg);
    public message_st *msgport_get(msgport_st *port);
    public int msgport_reply(message_st *msg);
}

