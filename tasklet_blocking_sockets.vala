/*
 *  This file is part of Netsukuku.
 *  (c) Copyright 2011-2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

namespace PthTasklet
{
    /** Use this class to implement a TCP connection oriented service or a unix-domain connection oriented service.
      * In particular, you can wait for a connection without blocking the
      *  rest of the application.
      */
    internal class ServerStreamSocket : Object
    {
        private Socket s;
        private string listen_pathname;
        private bool bind_done;

        public ServerStreamSocket.network(string my_addr, uint16 my_tcp_port, int backlog = 5) throws Error
        {
            bind_done = false;
            listen_pathname = null;
            s = new Socket(SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.DEFAULT);
            s.bind(new InetSocketAddress(new InetAddress.from_string(my_addr), my_tcp_port), true);
            bind_done = true;
            s.set_listen_backlog(backlog);
            s.listen();
        }

        public ServerStreamSocket.local(string listen_pathname, int backlog = 5) throws Error
        {
            bind_done = false;
            this.listen_pathname = listen_pathname;
            s = new Socket(SocketFamily.UNIX, SocketType.STREAM, SocketProtocol.DEFAULT);
            s.bind(new UnixSocketAddress(listen_pathname), true);
            bind_done = true;
            s.set_listen_backlog(backlog);
            s.listen();
        }

        /** When the method returns, start a new tasklet and pass the
          *  returned object to handle the request. With this instance,
          *  instead, call accept again to wait for more clients.
          */
        public ConnectedStreamSocket accept() throws Error
        {
            Socket s2 = PthThread.socket_accept(s);
            return new ConnectedStreamSocket.from_accept(s2);
        }

        public void close() throws Error
        {
            s.close();
            if (listen_pathname != null) FileUtils.unlink(listen_pathname);
        }

        ~ServerStreamSocket()
        {
            if (bind_done) close();
        }
    }

    /** Use this class to make a connection to a TCP service or to a unix-domain service.
      * In particular, you can wait for the connect to complete without
      *  blocking the rest of the application.
      */
    internal class ConnectedStreamSocket : Object
    {
        private Socket s;

        public ConnectedStreamSocket.from_accept(Socket s) throws Error
        {
            this.s = s;
        }

        public ConnectedStreamSocket.connect_network(string dest_addr, uint16 dest_tcp_port) throws Error
        {
            s = new Socket(SocketFamily.IPV4, SocketType.STREAM, SocketProtocol.DEFAULT);
            SocketAddress addr = new InetSocketAddress(new InetAddress.from_string(dest_addr), dest_tcp_port);
            PthThread.socket_connect(s, addr);
        }

        public ConnectedStreamSocket.connect_local(string send_pathname) throws Error
        {
            s = new Socket(SocketFamily.UNIX, SocketType.STREAM, SocketProtocol.DEFAULT);
            SocketAddress addr = new UnixSocketAddress(send_pathname);
            PthThread.socket_connect(s, addr);
        }

        public size_t send_part_new(uint8* b, size_t len) throws Error
        {
            return PthThread.socket_send_new(s, b, len);
        }

        public size_t recv_new(uint8* b, size_t maxlen) throws Error
        {
            return PthThread.socket_recv_new(s, b, maxlen);
        }

        public void close() throws Error
        {
            s.close();
        }
    }

    /** Use this class to listen to single broadcast datagrams on UDP bindtodevice or unix-domain.
      * The call to recvfrom blocks only the current tasklet, not the whole
      *  application.
      */
    internal class ServerDatagramSocket : Object
    {
        private Socket s;
        private string listen_pathname;
        private bool bind_done;

        public ServerDatagramSocket.network(uint16 udp_port, string my_dev) throws Error
        {
            bind_done = false;
            listen_pathname = null;
            s = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.DEFAULT);
            sk_bindtodevice(s, my_dev);
            s.bind(new InetSocketAddress(new InetAddress.any(SocketFamily.IPV4), udp_port), true);
            bind_done = true;
        }

        public ServerDatagramSocket.local(string listen_pathname) throws Error
        {
            bind_done = false;
            this.listen_pathname = listen_pathname;
            s = new Socket(SocketFamily.UNIX, SocketType.DATAGRAM, SocketProtocol.DEFAULT);
            s.bind(new UnixSocketAddress(listen_pathname), true);
            bind_done = true;
        }

        public size_t recvfrom_new(uint8* b, size_t maxlen) throws Error
        {
            return PthThread.socket_recvfrom_new(s, b, maxlen);
        }

        public void close() throws Error
        {
            s.close();
            if (listen_pathname != null) FileUtils.unlink(listen_pathname);
        }

        ~ServerDatagramSocket()
        {
            if (bind_done) close();
        }
    }

    /** Use this class to send a single broadcast datagram on UDP bindtodevice or unix-domain.
      */
    internal class ClientDatagramSocket : Object
    {
        private Socket s;
        private uint16 udp_port;
        private string send_pathname;
        public string dev {get; private set;}

        public ClientDatagramSocket.network(uint16 udp_port, string my_dev) throws Error
        {
            send_pathname = null;
            this.udp_port = udp_port;
            s = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.DEFAULT);
            sk_bindtodevice(s, dev);
            sk_setbroadcast(s);
        }

        public ClientDatagramSocket.local(string send_pathname) throws Error
        {
            this.send_pathname = send_pathname;
            s = new Socket(SocketFamily.UNIX, SocketType.DATAGRAM, SocketProtocol.DEFAULT);
        }

        public size_t sendto_new(uint8* b, size_t len) throws Error
        {
            SocketAddress addr;
            if (send_pathname != null)
                addr = new UnixSocketAddress(send_pathname);
            else
                addr = new InetSocketAddress(new InetAddress.any(SocketFamily.IPV4), udp_port);
            return PthThread.socket_sendto_new(s, addr, b, len);
        }

        public void close() throws Error
        {
            s.close();
        }

        ~ClientDatagramSocket()
        {
            close();
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

