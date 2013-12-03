/*
 *  This file is part of Netsukuku.
 *  (c) Copyright 2011 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

/** This module allows the developer to use sockets API with a blocking-like style
  *  and makes sure that only the intended tasklet becomes blocked, not
  *  the whole application.
  */

using Gee;
using Wrapped.LibPth;

namespace Tasklets
{
    /** Emulate inet_ntop and pton. In python we have:
            >>> socket.inet_ntop(socket.AF_INET,'1234')
            '49.50.51.52'
            >>> socket.inet_pton(socket.AF_INET,'49.50.51.52')
            '1234'
      * These emulation will work only with IPV4.
      * For now this is not a problem because IPV6 is currently disabled.
      */
    public string s_addr_to_string(string family, uint32 s_addr)
    {
        assert(family == "AF_INET");
        Posix.SockAddrIn saddr = Posix.SockAddrIn();
        saddr.sin_addr.s_addr = Posix.htonl(s_addr);
        return Posix.inet_ntoa(saddr.sin_addr);
    }
    public uint32 string_to_s_addr(string family, string dotted)
    {
        assert(family == "AF_INET");
        return Posix.ntohl(Posix.inet_addr(dotted));
    }
    public string pip_to_dotted(string family, uchar[] pip)
    {
        assert(pip.length == 4);
        int a1 = (int)pip[0];
        int a2 = (int)pip[1];
        int a3 = (int)pip[2];
        int a4 = (int)pip[3];
        uint32 s_addr = a4 + a3*256 + a2*256*256 + a1*256*256*256;
        return s_addr_to_string(family, s_addr);
    }
    public uchar[] dotted_to_pip(string family, string dotted)
    {
        uint32 s_addr = string_to_s_addr(family, dotted);
        int a1 = (int)(s_addr / (256*256*256));
        s_addr -= a1*256*256*256;
        int a2 = (int)(s_addr / (256*256));
        s_addr -= a2*256*256;
        int a3 = (int)(s_addr / 256);
        s_addr -= a3*256;
        int a4 = (int)(s_addr);
        uchar c1 = (uchar)a1;
        uchar c2 = (uchar)a2;
        uchar c3 = (uchar)a3;
        uchar c4 = (uchar)a4;
        uchar[] ret = new uchar[] {c1, c2, c3, c4};
        return ret;
    }

    /** When you have a socket connected to a server, or when you receive
      *  a connection, you get an obscure object that implements this API.
      */
    public interface IConnectedStreamSocket : Object
    {
        public uint16 peer_port {
            get {
                return this._peer_port_getter();
            }
        }
        public abstract uint16 _peer_port_getter();

        public string peer_address {
            get {
                return this._peer_address_getter();
            }
        }
        public abstract unowned string _peer_address_getter();

        public uint16 my_port {
            get {
                return this._my_port_getter();
            }
        }
        public abstract uint16 _my_port_getter();

        public string my_address {
            get {
                return this._my_address_getter();
            }
        }
        public abstract unowned string _my_address_getter();

        /** Sends all the bytes. Returns when all the bytes have been reliably sent.
          */
        public void send(uchar[] data) throws Error
        {
            int remain = data.length;
            while (remain > 0)
            {
                int done = send_part(data, remain);
                remain -= done;
                data = data[done:done+remain];
            }
        }

        protected abstract int send_part(uchar[] data, int maxlen) throws Error;
        public abstract uchar[] recv(int maxlen) throws Error;
        public abstract void close() throws Error;
    }

    /** Use this class to implement a TCP connection oriented service.
      * In particular, you can wait for a connection without blocking the
      *  rest of the application.
      */
    public class ServerStreamSocket : Object
    {
        private Socket s;

        public ServerStreamSocket(uint16 port, int backlog = 5, string? my_addr = null) throws Error
        {
            s = new Socket(SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP);
            if (my_addr == null)
                s.bind(new InetSocketAddress(new InetAddress.any(SocketFamily.IPV4), port), true);
            else
                s.bind(new InetSocketAddress(new InetAddress.from_string(my_addr), port), true);
            s.set_listen_backlog(backlog);
            s.listen();
        }

        /** When the method returns, start a new tasklet and pass the
          *  returned object to handle the request. With this instance,
          *  instead, call accept again to wait for more clients.
          */
        public IConnectedStreamSocket accept() throws Error
        {
            Tasklet.tasklet_leaves("with socket_accept");
            Socket s2 = PthThread.socket_accept(s);
            Tasklet.tasklet_regains("from socket_accept");
            return new ConnectedStreamSocket(s2);
        }

        public void close() throws Error
        {
            s.close();
        }

        ~ServerStreamSocket()
        {
            close();
        }
    }

    /** Use this class to make a connection to a TCP service.
      * In particular, you can wait for the connect to complete without
      *  blocking the rest of the application.
      */
    public class ClientStreamSocket : Object
    {
        private Socket s;

        public ClientStreamSocket(string? my_addr = null) throws Error
        {
            s = new Socket(SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.TCP);
            if (my_addr != null)
                s.bind(new InetSocketAddress(new InetAddress.from_string(my_addr), 0), false);
        }

        /** When the method returns, use the returned object
          *  to carry on the communication. Discard this instance, instead.
          */
        public IConnectedStreamSocket socket_connect(string addr, uint16 port) throws Error
        {
            assert(s != null);
            Tasklet.tasklet_leaves("with socket_connect");
            PthThread.socket_connect(s, addr, port);
            Tasklet.tasklet_regains("from socket_connect");
            IConnectedStreamSocket ret = new ConnectedStreamSocket(s);
            s = null;
            return ret;
        }
    }

    class ConnectedStreamSocket : Object, IConnectedStreamSocket
    {
        private Socket s;
        private string remote_addr;
        private uint16 remote_port;
        private string local_addr;
        private uint16 local_port;
        public ConnectedStreamSocket(Socket soc) throws Error
        {
            s = soc;
            InetSocketAddress x = (InetSocketAddress)s.get_remote_address();
            remote_addr = x.address.to_string();
            remote_port = (uint16)x.port;
            InetSocketAddress y = (InetSocketAddress)s.get_local_address();
            local_addr = y.address.to_string();
            local_port = (uint16)y.port;
        }

        public uint16 _peer_port_getter()
        {
            return remote_port;
        }

        public unowned string _peer_address_getter()
        {
            return remote_addr;
        }

        public uint16 _my_port_getter()
        {
            return local_port;
        }

        public unowned string _my_address_getter()
        {
            return local_addr;
        }

        protected int send_part(uchar[] data, int maxlen) throws Error
        {
            uchar[] buffer = new uchar[maxlen];
            Posix.memcpy(buffer, data, maxlen);
            Tasklet.tasklet_leaves("with socket_send");
            int ret = (int)PthThread.socket_send(s, buffer);
            Tasklet.tasklet_regains("from socket_send");
            return ret;
        }

        public uchar[] recv(int maxlen) throws Error
        {
            uchar[] ret;
            Tasklet.tasklet_leaves("with socket_recv");
            PthThread.socket_recv(s, out ret, maxlen);
            Tasklet.tasklet_regains("from socket_recv");
            return ret;
        }

        public void close() throws Error
        {
            s.close();
        }
    }

    /** Use this class to implement a UDP datagram oriented service.
      * The call to recvfrom blocks only the current tasklet, not the whole
      *  application.
      * You can use this same object to send a response to the caller.
      * Or else handle the request on another tasklet and, when necessary,
      *  use an BroadcastClientDatagramSocket to send a reply.
      */
    public class ServerDatagramSocket : Object
    {
        private Socket s;

        public ServerDatagramSocket(uint16 port, string? bind_ip = null, string? dev = null) throws Error
        {
            s = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            if (dev != null)
                sk_bindtodevice(s, dev);
            if (bind_ip == null)
                s.bind(new InetSocketAddress(new InetAddress.any(SocketFamily.IPV4), port), true);
            else
                s.bind(new InetSocketAddress(new InetAddress.from_string(bind_ip), port), true);
        }

        public uchar[] recvfrom(int maxsize, out string rmt_ip, out uint16 rmt_port) throws Error
        {
            uchar[] ret;
            Tasklet.tasklet_leaves("with socket_recvfrom");
            PthThread.socket_recvfrom(s, out ret, maxsize, out rmt_ip, out rmt_port);
            Tasklet.tasklet_regains("from socket_recvfrom");
            return ret;
        }

        public void sendto(uchar[] mesg, string rmt_ip, uint16 rmt_port) throws Error
        {
            Tasklet.tasklet_leaves("with socket_sendto");
            PthThread.socket_sendto(s, mesg, rmt_ip, rmt_port);
            Tasklet.tasklet_regains("from socket_sendto");
        }

        public void close() throws Error
        {
            s.close();
        }

        ~ServerDatagramSocket()
        {
            close();
        }
    }

    /** Use this class to send a single UDP datagram in broadcast over
      *  a particular interface.
      */
    public class BroadcastClientDatagramSocket : Object
    {
        private Socket s;
        private uint16 port;
        public string dev {get; private set;}

        public BroadcastClientDatagramSocket(string dev, uint16 port) throws Error
        {
            this.port = port;
            this.dev = dev;
            s = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            sk_bindtodevice(s, dev);
            sk_setbroadcast(s);
        }

        public void send(uchar[] mesg) throws Error
        {
            Tasklet.tasklet_leaves("with socket_sendtobroad");
            PthThread.socket_sendto(s, mesg, "255.255.255.255", port);
            Tasklet.tasklet_regains("from socket_sendtobroad");
        }

        public void close() throws Error
        {
            s.close();
        }
    }

    void sk_bindtodevice(Socket s, string ifname) throws Error
    {
        // TODO if sys.platform == 'linux2':
        // max len for ifr_name is 16
        assert(ifname.length <= 16);
        // bind to device
        int fd = s.get_fd();
        Linux.Network.IfReq xx = Linux.Network.IfReq();
        Posix.memcpy(&xx.ifr_name, ifname.data, ifname.length);
        int ret = Posix.setsockopt(fd, Posix.SOL_SOCKET, Posix.SO_BINDTODEVICE, &xx, (Posix.socklen_t)sizeof(Linux.Network.IfReq));
        int errnum = errno;
        if (ret != 0)
            throw new IOError.FAILED(@"setsockopt(BINDTODEVICE, $(ifname)): $(strerror(errnum))");
    }

    void sk_setbroadcast(Socket s) throws Error
    {
        // TODO if settings.IP_VERSION == 4:
        int broadcast_value = 1;
        int fd = s.get_fd();
        int ret = Posix.setsockopt(fd, Posix.SOL_SOCKET, Posix.SO_BROADCAST, &broadcast_value, (Posix.socklen_t)sizeof(int));
        int errnum = errno;
        if (ret != 0)
            throw new IOError.FAILED(@"setsockopt(BROADCAST, true): $(strerror(errnum))");
    }
}

