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

    public class NameTester : Object
    {
        public void set_up ()
        {
            logger = "";
        }

        public void tear_down ()
        {
            logger = "";
        }

        public void test_name()
        {
            Tasklet.tasklet_callback(() => {
                Tasklet t = Tasklet.self();
                int id = t.id;
                string name = t.name;
                print_out(@"$(name)\n");
                assert(@"id = $(id)" == name);
                // This test assures that if the Pth crashes it displays the id of the tasklet.
            });
            Tasklet.nap(0, 100000);
        }

        public static int main(string[] args)
        {
            GLib.Test.init(ref args);
            Tasklet.init();
            GLib.Test.add_func ("/Tasklet/Name", () => {
                var x = new NameTester();
                x.set_up();
                x.test_name();
                x.tear_down();
            });
            GLib.Test.run();
            Tasklet.kill();
            return 0;
        }
    }
}

/*

Produce a debuggable library 'tasklet' but do not install

e.g.

cd $(srcdir)
mkdir finalbuild
cd finalbuild
CFLAGS="-g -O0" LDFLAGS=-g ../configure --enable-logtasklet --prefix=/usr --disable-silent-rules
VALAFLAGS=-g make

Compile testname.vala with it:

cd $(srcdir)/testsuites/testname
valac -C -g \
   --pkg glib-2.0 \
   --pkg gio-2.0 \
   --pkg gee-0.8 \
   --pkg posix \
   testname.vala \
   ../../posix_extras.vapi \
   ../../libpth.vapi \
   ../../tasklet.vapi

( see /usr/share/vala/vapi/tasklet.deps )

gcc -c -g -O0 \
   $(pkg-config --cflags glib-2.0) \
   $(pkg-config --cflags gio-2.0) \
   $(pkg-config --cflags gee-0.8) \
   -I../.. \
   testname.c

libtool --mode=link gcc -g \
   -o testname \
   testname.o \
   $(pkg-config --libs glib-2.0) \
   $(pkg-config --libs gio-2.0) \
   $(pkg-config --libs gee-0.8) \
   ../../finalbuild/libtasklet.la

Debug with:

libtool --mode=execute nemiver ./testname

*/




