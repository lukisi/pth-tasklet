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
    const bool output = false;
    public void print_out(string s)
    {
        if (output) print(s);
    }

    public class CommandsTester : Object
    {
        public void set_up ()
        {
            logger = "";
        }

        public void tear_down ()
        {
            logger = "";
        }

        public void test_system()
        {
            Tasklet task0 = Tasklet.tasklet_callback(() => {
                // verify that this tasklet is responsive
                while (true)
                {
                    Timer t0 = new Timer(300);
                    Tasklet.nap(0, 1000);
                    print_out(".");stdout.flush();
                    if (t0.is_expired()) print_out("lag\n");
                }
            });
            Tasklet task1 = Tasklet.tasklet_callback(() => {
                // exec a long command
                Tasklet.system("sleep 0.3");
                print_out("\n");
            });
            Tasklet.nap(0, 800000);
            task0.abort();
            task1.abort();
        }

        public void test_exec_command()
        {
            Tasklet task0 = Tasklet.tasklet_callback(() => {
                // verify that this tasklet is responsive
                while (true)
                {
                    Timer t0 = new Timer(300);
                    Tasklet.nap(0, 1000);
                    print_out(".");stdout.flush();
                    if (t0.is_expired()) print_out("lag\n");
                }
            });
            Tasklet task1 = Tasklet.tasklet_callback(() => {
                // exec a long command
                Tasklet.exec_command("sleep 0.3");
                print_out("\n");
            });
            Tasklet.tasklet_callback(() => {
                // exec a long command
                CommandResult res = Tasklet.exec_command("ip a");
                print_out(res.cmdout);
            });
            Tasklet.nap(0, 800000);
            task0.abort();
            task1.abort();
        }

        public static int main(string[] args)
        {
            GLib.Test.init(ref args);
            Tasklet.init();
            GLib.Test.add_func ("/Tasklet/System", () => {
                var x = new CommandsTester();
                x.set_up();
                x.test_system();
                x.tear_down();
            });
            GLib.Test.add_func ("/Tasklet/Process", () => {
                var x = new CommandsTester();
                x.set_up();
                x.test_exec_command();
                x.tear_down();
            });
            GLib.Test.run();
            Tasklet.kill();
            return 0;
        }
    }
}
