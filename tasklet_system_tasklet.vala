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

        public TaskletCommandResult exec_command(string cmdline) throws Error
        {
            TaskletCommandResult ret = new TaskletCommandResult();
            PthTasklet.CommandResult res = PthTasklet.Tasklet.exec_command(cmdline);
            ret.exit_status = res.exit_status;
            ret.stdout = res.cmdout;
            ret.stderr = res.cmderr;
            return ret;
        }

        public IServerStreamSocket get_server_stream_socket(uint16 port, string? my_addr=null) throws Error
        {
            PthTasklet.ServerStreamSocket s = new PthTasklet.ServerStreamSocket(port, 5, my_addr);
            return new MyServerStreamSocket(s);
        }

        public IConnectedStreamSocket get_client_stream_socket(string dest_addr, uint16 dest_port, string? my_addr=null) throws Error
        {
            PthTasklet.ClientStreamSocket s = new PthTasklet.ClientStreamSocket(my_addr);
            return new MyConnectedStreamSocket(s.socket_connect(dest_addr, dest_port));
        }

        public IServerDatagramSocket get_server_datagram_socket(uint16 port, string dev) throws Error
        {
            PthTasklet.ServerDatagramSocket s = new PthTasklet.ServerDatagramSocket(port, null, dev);
            return new MyServerDatagramSocket(s);
        }

        public IClientDatagramSocket get_client_datagram_socket(uint16 port, string dev, string? my_addr=null) throws Error
        {
            return new MyClientDatagramSocket(new PthTasklet.BroadcastClientDatagramSocket(dev, port, my_addr));
        }

        public IChannel get_channel()
        {
            return new MyChannel();
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

        private class MyServerStreamSocket : Object, IServerStreamSocket
        {
            private PthTasklet.ServerStreamSocket c;
            public MyServerStreamSocket(PthTasklet.ServerStreamSocket c)
            {
                this.c = c;
            }

            public IConnectedStreamSocket accept() throws Error
            {
                return new MyConnectedStreamSocket(c.accept());
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyConnectedStreamSocket : Object, IConnectedStreamSocket
        {
            private PthTasklet.IConnectedStreamSocket c;
            public MyConnectedStreamSocket(PthTasklet.IConnectedStreamSocket c)
            {
                this.c = c;
            }

            public unowned string _peer_address_getter() {return c.peer_address;}
            public unowned string _my_address_getter() {return c.my_address;}

            public size_t recv(uint8* b, size_t maxlen) throws Error
            {
                return c.recv_new(b, maxlen);
            }

            public void send(uint8* b, size_t len) throws Error
            {
                c.send_new(b, len);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyServerDatagramSocket : Object, IServerDatagramSocket
        {
            private PthTasklet.ServerDatagramSocket c;
            public MyServerDatagramSocket(PthTasklet.ServerDatagramSocket c)
            {
                this.c = c;
            }

            public size_t recvfrom(uint8* b, size_t maxlen, out string rmt_ip, out uint16 rmt_port) throws Error
            {
                return c.recvfrom_new(b, maxlen, out rmt_ip, out rmt_port);
            }

            public void close() throws Error
            {
                c.close();
            }
        }

        private class MyClientDatagramSocket : Object, IClientDatagramSocket
        {
            private PthTasklet.BroadcastClientDatagramSocket c;
            public MyClientDatagramSocket(PthTasklet.BroadcastClientDatagramSocket c)
            {
                this.c = c;
            }

            public size_t sendto(uint8* b, size_t len) throws Error
            {
                return c.send_new(b, len);
            }

            public void close() throws Error
            {
                c.close();
            }
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
    }
}

