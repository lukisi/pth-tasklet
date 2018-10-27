/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2015-2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

using Gee;
using TaskletSystem;

namespace PthTaskletImplementer
{
    public ITasklet get_tasklet_system()
    {
        return new TaskletSystemImplementer();
    }

    public void init()
    {
        assert(PthTasklet.Tasklet.init());
    }

    public void kill()
    {
        assert(PthTasklet.Tasklet.kill());
    }

    internal class TaskletSystemImplementer : Object, ITasklet
    {
        private static int ind;
        private static HashMap<int,ITaskletSpawnable> map;

        private void * real_func(MyHandle h)
        {
            void * ret = h.sp.func();
            map.unset(h.ind);
            return ret;
        }

        internal TaskletSystemImplementer()
        {
            ind = 0;
            map = new HashMap<int,ITaskletSpawnable>();
        }

        public void schedule()
        {
            PthTasklet.Tasklet.schedule();
        }

        public void ms_wait(int msec)
        {
            PthTasklet.ms_wait(msec);
        }

        [NoReturn]
        public void exit_tasklet(void * ret)
        {
            PthTasklet.Tasklet.exit_current_thread(ret);
            assert_not_reached();
        }

        public ITaskletHandle spawn(ITaskletSpawnable sp, bool joinable=false)
        {
            MyHandle h = new MyHandle();
            h.ind = ind;
            h.sp = sp;
            h.joinable = joinable;
            map[ind] = sp;
            ind++;
            h.t = PthTasklet.Tasklet.tasklet_callback((_h) => {
                MyHandle t_h = (MyHandle)_h;
                real_func(t_h);
            }, h, null, null, null, joinable);
            return h;
        }

        private class MyHandle : Object, ITaskletHandle
        {
            public int ind;
            public ITaskletSpawnable sp;
            public PthTasklet.Tasklet t;
            public bool joinable;

            public bool is_running()
            {
                return map.has_key(ind);
            }

            public void kill()
            {
                t.abort();
            }

            public bool is_joinable()
            {
                return joinable;
            }

            public void * join()
            {
                if (!joinable) error("Tasklet not joinable");
                return t.join();
            }
        }

        public TaskletCommandResult exec_command_argv(Gee.List<string> argv) throws Error
        {
            TaskletCommandResult ret = new TaskletCommandResult();
            PthTasklet.CommandResult res = PthTasklet.Tasklet.exec_command(argv);
            ret.exit_status = res.exit_status;
            ret.stdout = res.cmdout;
            ret.stderr = res.cmderr;
            return ret;
        }

        public IChannel get_channel()
        {
            return new MyChannel();
        }

        private class MyChannel : Object, IChannel
        {
            private PthTasklet.Channel ch;
            internal MyChannel()
            {
                ch = new PthTasklet.Channel();
            }

            public void send(Value v)
            {
                ch.send(v);
            }

            public void send_async(Value v)
            {
                ch.send_async(v);
            }

            public int get_balance()
            {
                return ch.balance;
            }

            public Value recv()
            {
                return ch.recv();
            }

            public Value recv_with_timeout(int timeout_msec) throws ChannelError.TIMEOUT
            {
                try {
                    return ch.recv_with_timeout(timeout_msec);
                } catch (PthTasklet.ChannelError e) {
                    throw new ChannelError.TIMEOUT(e.message);
                }
            }
        }

        public size_t read(int fd, void* b, size_t maxlen) throws Error
        {
            return PthTasklet.Tasklet.read(fd, b, maxlen);
        }

        public size_t write(int fd, void* b, size_t count) throws Error
        {
            return PthTasklet.Tasklet.write(fd, b, count);
        }


        public IServerStreamNetworkSocket get_server_stream_network_socket(string my_addr, uint16 my_tcp_port) throws Error
        {
            return new NewServerStreamSocket(new PthTasklet.ServerStreamSocket.network(my_addr, my_tcp_port));
        }

        public IConnectedStreamNetworkSocket get_client_stream_network_socket(string dest_addr, uint16 dest_tcp_port) throws Error
        {
            return new NewConnectedStreamSocket(new PthTasklet.ConnectedStreamSocket.connect_network(dest_addr, dest_tcp_port));
        }

        public IServerDatagramNetworkSocket get_server_datagram_network_socket(uint16 udp_port, string my_dev) throws Error
        {
            return new NewServerDatagramSocket(new PthTasklet.ServerDatagramSocket.network(udp_port, my_dev));
        }

        public IClientDatagramNetworkSocket get_client_datagram_network_socket(uint16 udp_port, string my_dev) throws Error
        {
            return new NewClientDatagramSocket(new PthTasklet.ClientDatagramSocket.network(udp_port, my_dev));
        }


        public IServerStreamLocalSocket get_server_stream_local_socket(string listen_pathname) throws Error
        {
            return new NewServerStreamSocket(new PthTasklet.ServerStreamSocket.local(listen_pathname));
        }

        public IConnectedStreamLocalSocket get_client_stream_local_socket(string send_pathname) throws Error
        {
            return new NewConnectedStreamSocket(new PthTasklet.ConnectedStreamSocket.connect_local(send_pathname));
        }

        public IServerDatagramLocalSocket get_server_datagram_local_socket(string listen_pathname) throws Error
        {
            return new NewServerDatagramSocket(new PthTasklet.ServerDatagramSocket.local(listen_pathname));
        }

        public IClientDatagramLocalSocket get_client_datagram_local_socket(string send_pathname) throws Error
        {
            return new NewClientDatagramSocket(new PthTasklet.ClientDatagramSocket.local(send_pathname));
        }


        private class NewServerStreamSocket : Object,
                IServerStreamSocket, IServerStreamNetworkSocket, IServerStreamLocalSocket
        {
            private PthTasklet.ServerStreamSocket s;

            public NewServerStreamSocket(PthTasklet.ServerStreamSocket s)
            {
                this.s = s;
            }

            public IConnectedStreamSocket accept() throws Error
            {
                return new NewConnectedStreamSocket(s.accept());
            }

            public void close() throws Error
            {
                s.close();
            }
        }

        private class NewConnectedStreamSocket : Object,
                IConnectedStreamSocket, IConnectedStreamNetworkSocket, IConnectedStreamLocalSocket
        {
            private PthTasklet.ConnectedStreamSocket s;

            public NewConnectedStreamSocket(PthTasklet.ConnectedStreamSocket s)
            {
                this.s = s;
            }

            public size_t recv(uint8* b, size_t maxlen) throws Error
            {
                return s.recv_new(b, maxlen);
            }

            public size_t send_part(uint8* b, size_t len) throws Error
            {
                return s.send_part_new(b, len);
            }

            public void close() throws Error
            {
                s.close();
            }
        }

        private class NewServerDatagramSocket : Object,
                IServerDatagramSocket, IServerDatagramNetworkSocket, IServerDatagramLocalSocket
        {
            private PthTasklet.ServerDatagramSocket s;

            public NewServerDatagramSocket(PthTasklet.ServerDatagramSocket s)
            {
                this.s = s;
            }

            public size_t recvfrom(uint8* b, size_t maxlen) throws Error
            {
                return s.recvfrom_new(b, maxlen);
            }

            public void close() throws Error
            {
                s.close();
            }
        }

        private class NewClientDatagramSocket : Object,
                IClientDatagramSocket, IClientDatagramNetworkSocket, IClientDatagramLocalSocket
        {
            private PthTasklet.ClientDatagramSocket s;

            public NewClientDatagramSocket(PthTasklet.ClientDatagramSocket s)
            {
                this.s = s;
            }

            public size_t sendto(uint8* b, size_t len) throws Error
            {
                return s.sendto_new(b, len);
            }

            public void close() throws Error
            {
                s.close();
            }
        }
    }
}

