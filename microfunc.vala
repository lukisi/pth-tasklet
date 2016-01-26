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

/** The tester for this module contains sample code for how to simulate the decoration
  * of functions/methods as microfunc (simple or with dispatcher)
  */

using Gee;

namespace PthTasklet
{
    internal struct struct_channel
    {
        public Channel self;
    }

    /** The class TaskletDispatcher is not meant to create instances.
      * Its static method get_channel_for_helper is used to register an helper
      * that will act as a dispatcher for a function/method that we want to be
      * executed once at a time in a dedicated tasklet.
      *
      * An example is the method "dispatched" of the class "Microfuncs" in the tester.
      */
    internal class TaskletDispatcher : Object
    {
        class Record : Object
        {
            public Channel ch;
            public Tasklet t;
        }
        private static HashMap<Spawnable, Record> _records;
        private static HashMap<Spawnable, Record> records {
            get {
                if (_records == null) _records = new HashMap<Spawnable, Record>();
                return _records;
            }
        }
        public static Channel get_channel_for_helper(Spawnable f, int stacksize=-1)
        {
            Channel? retval = null;
            if (records.has_key(f))
            {
                // retrieves the info
                Record rec = records[f];
                // check that tasklet dispatcher is alive
                if (rec.t.is_dead())
                {
                    // remove the info
                    records.unset(f);
                }
                else
                {
                    // the channel is ok
                    retval = rec.ch;
                }
            }
            if (retval == null)
            {
                // creates a channel for driving the dispatcher
                Channel ch = new Channel();
                struct_channel st_ch = struct_channel();
                st_ch.self = ch;
                // spawns the dispatcher
                Tasklet t;
                if (stacksize == -1)
                    t = Tasklet.spawn(f, &st_ch);
                else
                    t = Tasklet.spawn(f, &st_ch, false, stacksize);
                // registers the info
                Record rec = new Record();
                rec.ch = ch;
                rec.t = t;
                records[f] = rec;
                // returns the channel to drive the call
                retval = rec.ch;
            }
            return retval;
        }
        public static void abort_all()
        {
            foreach (Record rec in records.values)
            {
                Tasklet t = rec.t;
                if (t != null && !t.is_dead()) t.abort();
            }
            records.clear();
        }
    }
}

