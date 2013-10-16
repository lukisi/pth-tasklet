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

namespace Ntk.Lib
{
    public void ms_wait(long msec)
    {
        long sec = msec / 1000;
        long undersec = msec - sec * 1000;
        long usec = undersec * 1000;
        Tasklet.nap(sec, usec);
    }

    /** Class for "timeouts" or "timespans"
      */
    public class Timer : Object
    {
        protected TimeVal exp;
        public Timer(long msec_ttl)
        {
            set_time(msec_ttl);
        }

        protected void set_time(long msec_ttl)
        {
            exp = TimeVal();
            exp.get_current_time();
            exp.add(msec_ttl*1000);
        }

        protected long get_msec_ttl()
        {
            TimeVal now = TimeVal();
            now.get_current_time();
            long sec = exp.tv_sec - now.tv_sec;
            long usec = exp.tv_usec - now.tv_usec;
            while (usec < 0)
            {
                usec += 1000000;
                sec--;
            }
            return sec*1000 + usec/1000;
        }

        public bool is_younger(Timer t)
        {
            if (exp.tv_sec > t.exp.tv_sec) return true;
            if (exp.tv_sec < t.exp.tv_sec) return false;
            if (exp.tv_usec > t.exp.tv_usec) return true;
            return false;
        }

        public bool is_expired()
        {
            return get_msec_ttl() < 0;
        }

        public string get_string_msec_ttl()
        {
            return @"$(get_msec_ttl())";
        }
    }
}
