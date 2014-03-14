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
    public void ms_wait(int64 msec)
    {
        int64 sec = msec / (int64)1000;
        int64 undersec = msec - sec * (int64)1000;
        int64 usec = undersec * (int64)1000;
        Tasklet.nap((long)sec, (long)usec);
    }

    /** Class for "timeouts" or "timespans"
      */
    public class Timer : Object
    {
        protected TimeVal exp;
        public Timer(int64 msec_ttl)
        {
            set_time(msec_ttl);
        }

        private static bool boundarychecked;
        protected void set_time(int64 msec_ttl)
        {
            exp = TimeVal();
            exp.get_current_time();
            long milli = (long)(msec_ttl % (int64)1000);
            long seconds = (long)(msec_ttl / (int64)1000);
            int64 check_seconds = (int64)exp.tv_sec;
            check_seconds += (int64)seconds;
            if (!boundarychecked)
            {
                log_debug("Timer: going to assert timer does not exceed structure boundary.");
                boundarychecked = true;
            }
            assert(check_seconds <= long.MAX);
            exp.add(milli*1000);
            exp.tv_sec += seconds;
        }

        public int64 get_msec_ttl()
        {
            // It's dangerous to public as API get_msec_ttl
            //  because if it is used in order to compare 2 timers
            //  the caller program cannot take into consideration the
            //  time passed from the 2 calls to this method.
            // The right way to compare 2 timers is the method is_younger.
            TimeVal now = TimeVal();
            now.get_current_time();
            long sec = exp.tv_sec - now.tv_sec;
            long usec = exp.tv_usec - now.tv_usec;
            while (usec < 0)
            {
                usec += 1000000;
                sec--;
            }
            return (int64)sec * (int64)1000 + (int64)usec / (int64)1000;
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
