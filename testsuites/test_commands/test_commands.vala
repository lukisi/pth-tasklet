/*
 *  This file is part of Netsukuku.
 *  (c) Copyright 2014 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

using PthTasklet;

namespace PthTasklet.Test
{
    string logger;
    const bool output = true;
    public void print_out(string s)
    {
        if (output) print(s);
    }

    delegate void MySpawnFunc();
    class MySpawnable : Object, TaskletSystem.ITaskletSpawnable
    {
        public MySpawnable(MySpawnFunc x)
        {
            this.x = x;
        }
        private MySpawnFunc x;
        public void* func ()
        {
            x();
            return null;
        }
    }

    class Timer : Object
    {
        protected TimeVal exp;
        public Timer(int64 msec_ttl)
        {
            set_time(msec_ttl);
        }

        protected void set_time(int64 msec_ttl)
        {
            exp = TimeVal();
            exp.get_current_time();
            long milli = (long)(msec_ttl % (int64)1000);
            long seconds = (long)(msec_ttl / (int64)1000);
            int64 check_seconds = (int64)exp.tv_sec;
            check_seconds += (int64)seconds;
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

    public class CommandsTester : Object
    {
        private TaskletSystem.ITasklet tasklet;
        public void set_up (TaskletSystem.ITasklet tasklet)
        {
            this.tasklet = tasklet;
            logger = "";
        }

        public void tear_down ()
        {
            this.tasklet = null;
            logger = "";
        }

        public void test_exec_command()
        {
            TaskletSystem.ITaskletHandle task0 =
            tasklet.spawn(new MySpawnable(() => {
                // verify that this tasklet is responsive
                while (true)
                {
                    Timer t0 = new Timer(300);
                    tasklet.ms_wait(1);
                    print_out(".");stdout.flush();
                    if (t0.is_expired()) print_out("lag\n");
                }
            }));
            TaskletSystem.ITaskletHandle task1 =
            tasklet.spawn(new MySpawnable(() => {
                // exec a long command
                tasklet.exec_command("sleep 0.3");
                print_out("\n");
            }));
            tasklet.spawn(new MySpawnable(() => {
                tasklet.ms_wait(1);
                // exec a long command
                TaskletSystem.TaskletCommandResult res = tasklet.exec_command("ip a");
                print_out(res.stdout);
            }));
            tasklet.ms_wait(800);
            task0.kill();
            task1.kill();
        }

        public static int main(string[] args)
        {
            GLib.Test.init(ref args);
            PthTaskletImplementer.init();
            GLib.Test.add_func ("/Tasklet/ExecCommand", () => {
                var x = new CommandsTester();
                x.set_up(PthTaskletImplementer.get_tasklet_system());
                x.test_exec_command();
                x.tear_down();
            });
            GLib.Test.run();
            PthTaskletImplementer.kill();
            return 0;
        }
    }
}
