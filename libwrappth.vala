/*
 * libwrappth.vala - Vala wrapper for libpth.vapi which is a strict bindings of GNU Pth
 * Copyright (c) 2011 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 * License: GNU LGPL v3 as published by the Free Software Foundation
 */

using Gee;

namespace Wrapped.LibPth
{
    public const int MAX_PRIORITY = Native.LibPth.PRIO_MAX;
    public const int STD_PRIORITY = Native.LibPth.PRIO_STD;
    public const int MIN_PRIORITY = Native.LibPth.PRIO_MIN;

    public enum States
    {
        STATE_SCHEDULER = Native.LibPth.STATE_SCHEDULER,
        STATE_NEW = Native.LibPth.STATE_NEW,
        STATE_READY = Native.LibPth.STATE_READY,
        STATE_WAITING = Native.LibPth.STATE_WAITING,
        STATE_DEAD = Native.LibPth.STATE_DEAD,
    }

    public enum AttributeNames
    {
        ATTR_PRIO = Native.LibPth.ATTR_PRIO,
        ATTR_NAME = Native.LibPth.ATTR_NAME,
        ATTR_JOINABLE = Native.LibPth.ATTR_JOINABLE,
        ATTR_CANCEL_STATE = Native.LibPth.ATTR_CANCEL_STATE,
        ATTR_STACK_SIZE = Native.LibPth.ATTR_STACK_SIZE,
        ATTR_STACK_ADDR = Native.LibPth.ATTR_STACK_ADDR,
        ATTR_DISPATCHES = Native.LibPth.ATTR_DISPATCHES,
        ATTR_TIME_SPAWN = Native.LibPth.ATTR_TIME_SPAWN,
        ATTR_TIME_LAST = Native.LibPth.ATTR_TIME_LAST,
        ATTR_TIME_RAN = Native.LibPth.ATTR_TIME_RAN,
        ATTR_START_FUNC = Native.LibPth.ATTR_START_FUNC,
        ATTR_START_ARG = Native.LibPth.ATTR_START_ARG,
        ATTR_STATE = Native.LibPth.ATTR_STATE,
        ATTR_EVENTS = Native.LibPth.ATTR_EVENTS,
        ATTR_BOUND = Native.LibPth.ATTR_BOUND,
    }

    public bool init()
    {
        int ret = Native.LibPth.init();
        if (ret == 0) return false;
        Native.LibPth.pth_st *main_pth_st = Native.LibPth.self();
        PthThread.set_main_thread(main_pth_st);
        return true;
    }

    public bool kill()
    {
        int ret = Native.LibPth.kill();
        if (ret == 0) return false;
        return true;
    }

    public class Attribute : Object
    {
        internal Native.LibPth.attr_st *attr;
        public string? name = null;
        
        private static Attribute _DEFAULT;
        public static Attribute DEFAULT
        {
            get
            {
                if (_DEFAULT == null) _DEFAULT = new Attribute.with_default();
                return _DEFAULT;
            }
        }

        public Attribute()
        {
            attr = Native.LibPth.attr_new();
        }

        internal Attribute.with_default()
        {
            attr = Native.LibPth.ATTR_DEFAULT;
        }

        public void set_stacksize(int stacksize)
        {
            Native.LibPth.attr_set(attr, Native.LibPth.ATTR_STACK_SIZE, stacksize);
        }

        public bool IsBound()
        {
            int bound = 1;
            /*int retval =*/ Native.LibPth.attr_get(attr, Native.LibPth.ATTR_BOUND, &bound);
            // TODO if (retval == 0) throw new;
            return bound != 0;
        }

        ~Attribute()
        {
            if (attr != Native.LibPth.ATTR_DEFAULT)
            {
                Native.LibPth.attr_destroy(attr);
            }
        }
    }

    public class PseudoPointer : Object
    {
        public static bool equal_func(PseudoPointer a, PseudoPointer b) {return a.p == b.p;}
        public static uint hash_func(PseudoPointer a) {return (uint)a.p;}
        public int64 p;
        public PseudoPointer()
        {
            p = (int64)0;
        }
        public PseudoPointer.with_pth_st(Native.LibPth.pth_st *pth)
        {
            p = (int64)pth;
        }
    }

    public class PthThread : Object
    {
        private static PthThread? main = null;
        private static HashMap<PseudoPointer, PthThread> _threads;
        private static HashMap<PseudoPointer, PthThread> threads {
            get {
                if (_threads == null)
                {
                    _threads = new HashMap<PseudoPointer, PthThread>((HashDataFunc)PseudoPointer.hash_func, (EqualDataFunc)PseudoPointer.equal_func);
                }
                return _threads;
            }
        }

        // this is to be called only internally by init()
        public static void set_main_thread(Native.LibPth.pth_st *main_pth_st)
        {
            main = new PthThread();
            main.pth = main_pth_st;
            threads[new PseudoPointer.with_pth_st(main.pth)] = main;
        }

        public static bool is_main_thread()
        {
            return self() == main;
        }

        public static PthThread self()
        {
            Native.LibPth.pth_st *self_pth_st = Native.LibPth.self();
            PthThread ret = threads[new PseudoPointer.with_pth_st(self_pth_st)];
            return ret;
        }

        private Native.LibPth.pth_st *pth;

        public static PthThread spawn(Attribute attr, Native.LibPth.Spawnable f, void *user_data)
        {
            PthThread spawned = new PthThread();
            if (attr.name != null)
            {
                Native.LibPth.attr_set(attr.attr, Native.LibPth.ATTR_NAME, attr.name);
            }
            spawned.pth = Native.LibPth.spawn(attr.attr, f, user_data);
            threads[new PseudoPointer.with_pth_st(spawned.pth)] = spawned;
            return spawned;
        }

        private PthThread()
        {
        }

        public string get_name()
        {
            Native.LibPth.attr_st *attr = Native.LibPth.attr_of(pth);
            weak string name;
            Native.LibPth.attr_get(attr, Native.LibPth.ATTR_NAME, out name);
            Native.LibPth.attr_destroy(attr);
            return name;
        }

        public static bool equal_func(PthThread a, PthThread b) {return a.pth == b.pth;}
        public static uint hash_func(PthThread a) {return (uint)a.pth;}

        public void set_joinable(bool j)
        {
            Native.LibPth.attr_st *attr = Native.LibPth.attr_of(pth);
            Native.LibPth.attr_set(attr, 
                                   Native.LibPth.ATTR_JOINABLE, 
                                   (int)j);
            Native.LibPth.attr_destroy(attr);
        }

        public States get_state()
        {
            int state = 0;
            Native.LibPth.attr_st *attr = Native.LibPth.attr_of(pth);
            Native.LibPth.attr_get(attr, 
                                   Native.LibPth.ATTR_STATE, 
                                   &state);
            Native.LibPth.attr_destroy(attr);
            return (States)state;
        }

        public static void cancel_point()
        {
            Native.LibPth.cancel_point();
        }

        public void abort()
        {
            Native.LibPth.abort(pth);
        }

        public static void join(PthThread joinable, void **retval)
        {
            Native.LibPth.pth_st *_joinable = joinable.pth;
            int ret = Native.LibPth.join(_joinable, retval);
            if (ret != 0) return;
            critical("Tasklet: 'join' called on non-joinable tasklet.");
            assert_not_reached ();
        }
        
        public static void pth_yield(PthThread? next)
        {
            Native.LibPth.pth_st *_next = null;
            if (next != null)
                _next = next.pth;
            /*int retval =*/ Native.LibPth.pth_yield(_next);
            // TODO if (retval == 0) throw new;
        }
        
        public static void nap(long sec, long usec)
        {
            Native.LibPth.nap(Native.LibPth.time(sec, usec));
        }
        
        public static int system(string? command)
        {
            return Native.LibPth.system(command);
        }
        
        public static Socket socket_accept(Socket s) throws Error
        {
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            int fd2 = Native.LibPth.accept(fd, null, null);
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);

            // NOTE: NONBLOCK should be not set in new file descriptor fd2

            // from file_descriptor to Socket
            Socket ret = new Socket.from_fd(fd2);

            // NOTE: NONBLOCK should be set in new Socket object ret

            return ret;
        }
        
        public static void socket_connect(Socket s, string address, uint16 port) throws Error
        {
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            SocketAddress addr = new InetSocketAddress(new InetAddress.from_string(address), port);
            size_t destlen = addr.get_native_size();
            void *dest = malloc(destlen);
            addr.to_native(dest, destlen);
            int result = Native.LibPth.connect(fd, (Posix.SockAddr *)dest, destlen);
            if (result != 0) throw new IOError.CONNECTION_REFUSED(@"Error trying to connect to $(address):$(port)");
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
        }
        
        public static ssize_t socket_send(Socket s, uchar[] data) throws Error
        {
            assert(data.length > 0);
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            ssize_t result = Native.LibPth.send(fd, (void *)data, data.length, 0);
            if (result == 0) throw new IOError.CLOSED("Error trying to send to a connected socket");
            else if (result == -1) report_error("Native.LibPth.send");
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return result;
        }
        
        public static size_t socket_send_new(Socket s, uint8* b, size_t maxlen) throws Error
        {
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            ssize_t result = Native.LibPth.send(fd, (void *)b, maxlen, 0);
            if (result == 0) throw new IOError.CLOSED("Error trying to send to a connected socket");
            else if (result == -1) report_error("Native.LibPth.send");
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return (size_t)result;
        }
        
        public static ssize_t socket_recv(Socket s, out uchar[] data, int maxlen) throws Error
        {
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            uchar[] temp = new uchar[maxlen];
            ssize_t result = Native.LibPth.recv(fd, (void *)temp, maxlen, 0);
            if (result == 0) throw new IOError.CLOSED("Error trying to recv from a connected socket");
            else if (result == -1) report_error("Native.LibPth.recv");
            data = new uchar[result];
            Posix.memcpy(data, temp, result);
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return result;
        }
        
        public static size_t socket_recv_new(Socket s, uint8* b, size_t maxlen) throws Error
        {
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            ssize_t result = Native.LibPth.recv(fd, (void *)b, maxlen, 0);
            if (result == 0) throw new IOError.CLOSED("Error trying to recv from a connected socket");
            else if (result == -1) report_error("Native.LibPth.recv");
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return (size_t)result;
        }
        
        public static ssize_t socket_sendto(Socket s, uchar[] data, string address, uint16 port) throws Error
        {
            // For a broadcast packet use "255.255.255.255" as address and
            // use a socket 's' that has been set to broadcast.
            assert(data.length > 0);
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            SocketAddress addr = new InetSocketAddress(new InetAddress.from_string(address), port);
            size_t destlen = addr.get_native_size();
            void *dest = malloc(destlen);
            addr.to_native(dest, destlen);
            ssize_t result = Native.LibPth.sendto(fd, (void *)data, data.length, 0, (Posix.SockAddr *)dest, destlen);
            if (result == 0) throw new IOError.FAILED(@"Error trying to send to $(address):$(port)");
            else if (result == -1) report_error("Native.LibPth.sendto");
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return result;
        }
        
        public static size_t socket_sendto_new(Socket s, uint8* b, size_t len, string address, uint16 port) throws Error
        {
            // For a broadcast packet use "255.255.255.255" as address and
            // use a socket 's' that has been set to broadcast.

            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            SocketAddress addr = new InetSocketAddress(new InetAddress.from_string(address), port);
            size_t destlen = addr.get_native_size();
            void *dest = malloc(destlen);
            addr.to_native(dest, destlen);
            ssize_t result = Native.LibPth.sendto(fd, (void *)b, len, 0, (Posix.SockAddr *)dest, destlen);
            if (result == 0) throw new IOError.FAILED(@"Error trying to send to $(address):$(port)");
            else if (result == -1) report_error("Native.LibPth.sendto");
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return (size_t)result;
        }
        
        public static ssize_t socket_recvfrom(Socket s, out uchar[] data, int maxlen, out string rmt_ip, out uint16 rmt_port) throws Error
        {
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            //ssize_t recvfrom(int fd, void *buf, size_t buflen, int flags, Posix.SockAddr *addr, size_t *plen);
            uchar[] temp = new uchar[maxlen];
            Posix.SockAddrIn addr = Posix.SockAddrIn();
            size_t len = sizeof(Posix.SockAddrIn);
            ssize_t result = Native.LibPth.recvfrom(fd, (void *)temp, maxlen, 0, (Posix.SockAddr*)(&addr), &len);
            if (result == 0) throw new IOError.CLOSED("Error trying to recv from a udp socket");
            else if (result == -1) report_error("Native.LibPth.recvfrom");
            rmt_ip = "";
            rmt_port = 0;
            if (addr.sin_family == SocketFamily.IPV4)
            {
                rmt_port = Posix.ntohs(addr.sin_port);
                rmt_ip = Posix.inet_ntoa(addr.sin_addr);
            }
            data = new uchar[result];
            Posix.memcpy(data, temp, result);
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return result;
        }
        
        public static size_t socket_recvfrom_new(Socket s, uint8* b, size_t maxlen, out string rmt_ip, out uint16 rmt_port) throws Error
        {
            // from Socket to file_descriptor
            int fd = s.get_fd();
            // get current NONBLOCK flag
            int flags;
            if (-1 == (flags = Posix.fcntl(fd, Posix.F_GETFL, 0)))
                flags = 0;
            // unset NONBLOCK flag
            int newflags = flags & (~Posix.O_NONBLOCK);
            Posix.fcntl(fd, Posix.F_SETFL, newflags);
            // call blocking function with Pth support
            //ssize_t recvfrom(int fd, void *buf, size_t buflen, int flags, Posix.SockAddr *addr, size_t *plen);
            Posix.SockAddrIn addr = Posix.SockAddrIn();
            size_t len = sizeof(Posix.SockAddrIn);
            ssize_t result = Native.LibPth.recvfrom(fd, (void *)b, maxlen, 0, (Posix.SockAddr*)(&addr), &len);
            if (result == 0) throw new IOError.CLOSED("Error trying to recv from a udp socket");
            else if (result == -1) report_error("Native.LibPth.recvfrom");
            rmt_ip = "";
            rmt_port = 0;
            if (addr.sin_family == SocketFamily.IPV4)
            {
                rmt_port = Posix.ntohs(addr.sin_port);
                rmt_ip = Posix.inet_ntoa(addr.sin_addr);
            }
            // reset old NONBLOCK flag
            Posix.fcntl(fd, Posix.F_SETFL, flags);
            return (size_t)result;
        }

        public static size_t read(int fd, void* b, size_t nbytes) throws Error
        {
            // call blocking function with Pth support
            ssize_t result = Native.LibPth.read(fd, b, nbytes);
            if (result == -1) report_error("Native.LibPth.read");
            return (size_t)result;
        }

        public static size_t write(int fd, void* b, size_t nbytes) throws Error
        {
            // call blocking function with Pth support
            ssize_t result = Native.LibPth.write(fd, b, nbytes);
            if (result == -1) report_error("Native.LibPth.write");
            return (size_t)result;
        }

        /** This terminates the current thread. Whether it's immediately
          * removed from the system or inserted into the dead queue of the
          * scheduler depends on its join type which was specified at
          * spawning time. If it has the attribute PTH_ATTR_JOINABLE set to
          * FALSE, it's immediately removed and value is ignored. Else the
          * thread is inserted into the dead queue and value remembered for
          * a subsequent pth_join(3) call by another thread.
          * If invoked on the "main" thread this function waits for all
          * other threads to terminate, kills the threading system and then
          * terminates the process returning the value.
          */
        public static void exit(void *exit_val)
        {
            Native.LibPth.exit(exit_val);
        }

        [NoReturn]
        static void report_error(string funcname) throws Error
        {
            if (errno == Posix.EAGAIN)
                throw new IOError.WOULD_BLOCK(@"$(funcname) returned EAGAIN");
            if (errno == Posix.EWOULDBLOCK)
                throw new IOError.WOULD_BLOCK(@"$(funcname) returned EWOULDBLOCK");
            if (errno == Posix.EBADF)
                throw new IOError.FAILED(@"$(funcname) returned EBADF");
            if (errno == Posix.ECONNREFUSED)
                throw new IOError.CONNECTION_REFUSED(@"$(funcname) returned ECONNREFUSED");
            if (errno == Posix.EFAULT)
                throw new IOError.FAILED(@"$(funcname) returned EFAULT");
            if (errno == Posix.EINTR)
                throw new IOError.FAILED(@"$(funcname) returned EINTR");
            if (errno == Posix.EINVAL)
                throw new IOError.INVALID_ARGUMENT(@"$(funcname) returned EINVAL");
            if (errno == Posix.ENOMEM)
                throw new IOError.FAILED(@"$(funcname) returned ENOMEM");
            if (errno == Posix.ENOTCONN)
                throw new IOError.FAILED(@"$(funcname) returned ENOTCONN");
            if (errno == Posix.ENOTSOCK)
                throw new IOError.FAILED(@"$(funcname) returned ENOTSOCK");
            throw new IOError.FAILED(@"$(funcname) returned -1, errno = $(errno)");
        }
    }
}

