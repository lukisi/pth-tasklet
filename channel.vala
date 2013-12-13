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

using Gee;

namespace Tasklets
{
    public errordomain ChannelError {
        TIMEOUT_EXPIRED,
        GENERIC
    }

    /** A Channel object is used for bidirectional communication between tasklets.
      *
      * Features:
      *  * an object sent through an instance of Channel can be received only through the same instance of Channel;
      *  * an instance of Channel can have a name, and can be obtained by that name (static method find);
      *  * it is possible to send a message without blocking the current tasklet; not even scheduling;
      *  * it is possible for a tasklet to wait for a message to be received from a Channel;
      *    it is guaranteed that the order with which several tasklets wait a message is respected in the
      *    dispatching of messages; it is also possible for the tasklet to specify a timeout when waiting for a message;
      *  * it is possible to send a message and block the sending tasklet until the message is received;
      *  * it is possible to know how many messages are in a Channel to be received or
      *    how many tasklets are waiting to receive in a Channel (property balance)
      */
    public class Channel:Object
    {
        private class Message:Object
        {
            public Value wrapped;
            public Tasklet? confirmReceipt;
        }

        /* to support naming the channel and retrieving the instance */
        private static HashMap<string, Channel> _channels;
        private static HashMap<string, Channel> channels {
            get {
                if (_channels == null) _channels = new HashMap<string, Channel>();
                return _channels;
            }
        }
        /* to support naming the channel and retrieving the instance */

        private LinkedList<Message> pendingMessages;
        private ArrayList<Tasklet> taskletsWaitingForReceipt;
        private ArrayList<Tasklet> receivingTasklets;
        
        public Channel(string? name = null)
        {
            if (name != null) channels[name] = this;
            pendingMessages = new LinkedList<Message>();
            taskletsWaitingForReceipt = new ArrayList<Tasklet>((EqualDataFunc)Tasklet.equal_func);
            receivingTasklets = new ArrayList<Tasklet>((EqualDataFunc)Tasklet.equal_func);
        }

        public static Channel? find(string name)
        {
            if (channels.has_key(name)) return channels[name];
            return null;
        }

        /** A positive value indicates messages waiting to be received.
          * A negative value indicates tasklets waiting to receive a message.
          */
        public int balance {
            get {
                return pendingMessages.size - receivingTasklets.size;
            }
        }

        public void send_async(Value v)
        {
            Message msg = new Message();
            msg.wrapped = v;
            pendingMessages.offer(msg);
        }

        public void send(Value v)
        {
            Message msg = new Message();
            msg.wrapped = v;
            msg.confirmReceipt = Tasklet.self();
            taskletsWaitingForReceipt.add(msg.confirmReceipt);
            pendingMessages.offer(msg);
            while (taskletsWaitingForReceipt.contains(msg.confirmReceipt))
            {
                Tasklet.nap(0, 100);
            }
        }

        public Value recv()
        {
            try
            {
                return recv_implementation();
            }
            catch (ChannelError e)
            {
                assert(false);
            }
            // code never reached, but valac doesn't know and complains if we remove
            return Value(typeof(Object));
        }

        public Value recv_with_timeout(int timeout_msec) throws ChannelError
        {
            return recv_implementation(timeout_msec);
        }

        private Value recv_implementation(int? timeout_msec = null) throws ChannelError
        {
            Message retval;
            Timer? tc = null;
            if (timeout_msec != null)
            {
                tc = new Timer(timeout_msec);
            }
            receivingTasklets.add(Tasklet.self());
            while (true)
            {
                if (pendingMessages.size > 0)
                {
                    if (receivingTasklets[0] != Tasklet.self())
                    {
                        bool aborted = receivingTasklets[0].is_dead();
                        if (aborted)
                        {
                            receivingTasklets.remove_at(0);
                            continue;
                        }
                    }
                    else
                    {
                        receivingTasklets.remove_at(0);
                        retval = pendingMessages.poll();
                        if (retval.confirmReceipt != null)
                        {
                            taskletsWaitingForReceipt.remove(retval.confirmReceipt);
                        }
                        break;
                    }
                }
                Tasklet.nap(0, 10000);
                if (tc != null && tc.is_expired())
                {
                    receivingTasklets.remove(Tasklet.self());
                    throw new ChannelError.TIMEOUT_EXPIRED("Channel: recv timeout");
                }
            }
            return retval.wrapped;
        }
    }
}

