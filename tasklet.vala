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

using Gee;
using Wrapped.LibPth;

namespace PthTasklet
{
    [CCode (has_target = false)]
    internal delegate void * Spawnable (void* user_data) throws Error;

    internal delegate void TaskletCallback(Object? obj1, Object? obj2, Object? obj3, Object? obj4) throws Error;
    internal delegate bool ConditionFunc();

    struct struct_helper_tasklet_callback
    {
        public TaskletCallback y;
        public Object? obj1;
        public Object? obj2;
        public Object? obj3;
        public Object? obj4;
    }

    /** data for function exec_command.
      */

    char[] cmdout_buf = null;
    char[] cmderr_buf = null;
    const int buf_size = 20000;

    internal class CommandResult : Object
    {
        public string cmdout;
        public string cmderr;
        public int exit_status;
    }

    /** A Tasklet instance represents a thread that has been spawned to execute a
      * certain function.
      * In order to spawn a thread to execute a method of an object proceed this way:
      *  * prepare a function, or a static method, with the signature void *(*)(void *)
      *  * prepare a struct which will contain:
      *     * the instance of the class which the method is invoked in,
      *     * the parameters (simple types or objects) that will be passed.
      *  * in the function do this:
      *     * cast the void* to a pointer to your struct
      *     * if you pass a ref-counted class, assign it to a local variable in order to increase the refcounter
      *     * if you pass a simple type, assign it to a local variable in order to copy its value
      *     * call Tasklet.schedule_back() in order to let the caller decide when to start the new thread
      *     * call the method with the object and parameters that you just copied in local variables
      *  * when you want to spawn, allocate in the stack a struct of the type
      *  * populate the struct with data
      *  * call Tasklet.spawn(function, &my_struct)
      * The real function/method will not start immediately, but the struct can be safely freed right now.
      *
      * Features:
      *  * method schedule gives a chance to the scheduler to assign the cpu to other threads;
      *  * method schedule can select a particular tasklet to be scheduled;
      *  * method schedule_back schedules the previous tasklet;
      *  * method join waits for a thread to complete and can get a void* from it;
      *  * ...
      */
    internal class Tasklet : Object
    {
        private static Tasklet? main = null;
        private static HashMap<PthThread, Tasklet> _tasklets;
        private static HashMap<PthThread, Tasklet> tasklets {
            get {
                if (_tasklets == null) _tasklets = new HashMap<PthThread, Tasklet>((HashDataFunc)PthThread.hash_func, (EqualDataFunc)PthThread.equal_func);
                return _tasklets;
            }
        }
        private static int _default_thread_stack_size;

        public static bool init(int default_thread_stack_size = 64)
        {
            if (Wrapped.LibPth.init())
            {
                PthThread p_main = PthThread.self();
                main = new Tasklet();
                main.pth = p_main;
                tasklets[main.pth] = main;
                _default_thread_stack_size = default_thread_stack_size;
                return true;
            }
            return false;
        }

        /** Kills immediately the threading system.
          *
          * You can call it only from the main thread.
          */
        public static bool kill()
        {
            return Wrapped.LibPth.kill();
        }

        /** Exits the current thread.
          */
        public static void exit_current_thread(void *val)
        {
            assert(! Wrapped.LibPth.PthThread.is_main_thread());

            Wrapped.LibPth.PthThread.exit(val);
        }

        /** Waits for all the threads to complete and then
          * kills the threading system and exits the application.
          *
          * You can call it only from the main thread.
          */
        public static void exit_app(int val)
        {
            assert(Wrapped.LibPth.PthThread.is_main_thread());

            // According to Pth documentation, a call to pth_exit from the main thread
            //  should just work. But in certain scenarios (see tasklet_tester_2.vala)
            //  this wouldn't permit other spawned tasks to complete. The following line
            //  seems to be a workaround that just works.
            if (last_scheduling_tasklet != null) last_scheduling_tasklet.join();

            Wrapped.LibPth.PthThread.exit((void *)val);
        }

        private static Tasklet last_scheduling_tasklet;
        public static void schedule(Tasklet? next = null)
        {
            last_scheduling_tasklet = self();
            PthThread _next = null;
            if (next != null)
            {
                _next = next.pth;
            }
            /*int retval =*/ PthThread.pth_yield(_next);
            // TODO if (retval == 0) throw new;
        }

        public static void schedule_back()
        {
            schedule(last_scheduling_tasklet);
        }

        public static Tasklet self()
        {
            PthThread self_pth_thread = PthThread.self();
            Tasklet ret = tasklets[self_pth_thread];
            return ret;
        }

        public static void nap(long sec, long usec)
        {
            PthThread.nap(sec, usec);
        }

        public static int system(string? command)
        {
            return PthThread.system(command);
        }

        public static size_t read(int fd, void* b, size_t nbytes) throws Error
        {
            return PthThread.read(fd, b, nbytes);
        }

        public static size_t write(int fd, void* b, size_t nbytes) throws Error
        {
            return PthThread.write(fd, b, nbytes);
        }

        /** Launch a process and block this tasklet till it ends.
          * Returns exit status, stdout and stderr.
          */
        public static CommandResult exec_command(string[] argv) throws SpawnError
        {
            CommandResult com_ret = new CommandResult();
            com_ret.cmdout = "";
            com_ret.cmderr = "";
            com_ret.exit_status = 0;
            if (cmdout_buf == null) cmdout_buf = new char[buf_size];
            if (cmderr_buf == null) cmderr_buf = new char[buf_size];
            int buf_len = 200;
            size_t cmdout_i = 0;
            size_t cmderr_i = 0;
            char[] buf = new char[buf_len];
            Pid child_pid;
            int standard_output;
            int standard_error;
            Process.spawn_async_with_pipes(null, argv, null,
                SpawnFlags.DO_NOT_REAP_CHILD | SpawnFlags.SEARCH_PATH,
                null,
                out child_pid,
                null,
                out standard_output,
                out standard_error);
            int old_standard_output_flags = Posix.fcntl(standard_output, Posix.F_GETFL, 0);
            Posix.fcntl(standard_output, Posix.F_SETFL, old_standard_output_flags | Posix.O_NONBLOCK);
            int old_standard_error_flags = Posix.fcntl(standard_error, Posix.F_GETFL, 0);
            Posix.fcntl(standard_error, Posix.F_SETFL, old_standard_error_flags | Posix.O_NONBLOCK);
            bool exited = false;
            int waitpid_status = 0;
            while (true)
            {
                bool something_read = false;
                ssize_t s_tot = Posix.read(standard_output, (void *)buf, buf_len);
                if (s_tot == -1)
                {
                    if (Posix.errno == Posix.EAGAIN)
                    {
                        // simply no more data from stdout
                    }
                    else
                    {
                        throw new SpawnError.READ(@"Error while pipe-reading from stdout: errno = $(Posix.errno)");
                    }
                }
                else
                {
                    size_t tot = (size_t)s_tot;
                    // do not exceed buffer size
                    if (cmdout_i + tot >= buf_size) tot = buf_size - cmdout_i - 1;
                    if (tot > 0)
                    {
                        something_read = true;
                        Posix.memcpy(((char *)cmdout_buf)+cmdout_i, buf, tot);
                        cmdout_i += tot;
                    }
                }
                s_tot = Posix.read(standard_error, (void *)buf, buf_len);
                if (s_tot == -1)
                {
                    if (Posix.errno == Posix.EAGAIN)
                    {
                        // simply no more data from stderr
                    }
                    else
                    {
                        throw new SpawnError.READ(@"Error while pipe-reading from stdout: errno = $(Posix.errno)");
                    }
                }
                else
                {
                    size_t tot = (size_t)s_tot;
                    // do not exceed buffer size
                    if (cmdout_i + tot >= buf_size) tot = buf_size - cmdout_i - 1;
                    if (tot > 0)
                    {
                        something_read = true;
                        Posix.memcpy(((char *)cmderr_buf)+cmderr_i, buf, tot);
                        cmderr_i += tot;
                    }
                }
                if (!exited)
                {
                    Posix.pid_t ret = Posix.waitpid((Posix.pid_t)child_pid, out waitpid_status, Posix.WNOHANG);
                    if (ret != 0) exited = true;
                    else ms_wait(1);
                }
                if (exited)
                {
                    // perhaps more stuff to read
                    if (!something_read) break;
                }
            }
            Process.close_pid(child_pid);
            Posix.close(standard_output);
            Posix.close(standard_error);
            if (waitpid_status == -1)
            {
                warning(@"Tasklet: process '$(argv[0])' failed with errno = $(Posix.errno).");
                com_ret.exit_status = -1;
            }
            else if (Process.if_exited(waitpid_status))
            {
                com_ret.exit_status = Process.exit_status(waitpid_status);
            }
            else if (Process.if_signaled(waitpid_status))
            {
                debug(@"Tasklet: process '$(argv[0])' was terminated by a signal");
                com_ret.exit_status = (int)Process.term_sig(waitpid_status);
            }
            else if (Process.if_stopped(waitpid_status))
            {
                debug(@"Tasklet: process '$(argv[0])' was _stopped_ by a signal");
                com_ret.exit_status = (int)Process.stop_sig(waitpid_status);
            }
            else if (Process.core_dump(waitpid_status))
            {
                warning(@"Tasklet: process '$(argv[0])' core dumped.");
                com_ret.exit_status = -1;
            }
            cmdout_buf[cmdout_i] = '\0';
            cmderr_buf[cmderr_i] = '\0';
            com_ret.cmdout = (string)cmdout_buf;
            com_ret.cmderr = (string)cmderr_buf;

            return com_ret;
        }

        private static int next_id;
        private int my_id;
        private string? my_name = null;
        private Tasklet()
        {
            my_id = next_id++;
        }

        public static bool equal_func(Tasklet a, Tasklet b)
        {
            bool ret = a.my_id == b.my_id;
            return ret;
        }
        public static uint hash_func(Tasklet a)
        {
            uint ret = (uint)a.my_id;
            return ret;
        }

        public int id {
            get {
                return my_id;
            }
        }

        public string name {
            get {
                if (my_name == null) my_name = pth.get_name();
                return my_name;
            }
        }

        public static Tasklet spawn(Spawnable function, void *params_tuple_p, bool joinable=false, int stacksize=-1)
        {
            // alloc in heap the tasklet_function_params_tuple
            tasklet_function_params_tuple *function_params_tuple_p = malloc(sizeof(tasklet_function_params_tuple));
            // point to params_tuple from the tasklet_function_params_tuple
            function_params_tuple_p->function = function;
            function_params_tuple_p->params_tuple_p = params_tuple_p;
            // spawn
            Tasklet retval = new Tasklet();
            Attribute attr = new Attribute();
            attr.name = @"id = $(retval.id)";
            if (stacksize > 0) attr.set_stacksize(stacksize);
            else attr.set_stacksize(1024 * _default_thread_stack_size);
            retval.pth = PthThread.spawn(attr, (Native.LibPth.Spawnable)tasklet_marshaller, function_params_tuple_p);
            if (! joinable) retval.pth.set_joinable(joinable);
            tasklets[retval.pth] = retval;
            // Immediately schedule the helper_xxx function in order to do copies and/or refcounting.
            //  (see testsuite microfunc_tester_1.vala for an example)
            schedule(retval);
            // The helper_xxx function should pass the schedule back to me afterwards.
            free(function_params_tuple_p);
            return retval;
        }

        private PthThread pth;
        public void* join()
        {
            void *ret = null;
            PthThread.join(pth, &ret);
            return ret;
        }

        public bool is_dead()
        {
            return (pth.get_state() == States.STATE_DEAD);
        }

        public static void cancel_point()
        {
            PthThread.cancel_point();
        }

        public void abort()
        {
            pth.abort();
        }

        private struct tasklet_function_params_tuple
        {
            public Spawnable function;
            public void *params_tuple_p;
        }

        private static void *tasklet_marshaller(void *v)
        {
            void *result = null;
            try
            {
                tasklet_function_params_tuple *function_params_tuple_p = (tasklet_function_params_tuple *)v;
                result = function_params_tuple_p->function(function_params_tuple_p->params_tuple_p);
            }
            catch (Error e)
            {
                warning(@"a microfunc reported an error: $(e.message)");
            }
            return result;
        }

        /** The following methods provide a way to quickly spawn a tasklet implemented
          * by code written in a function or in a closure.
          * BEWARE that if the code is written in a closure it will misbehave if it
          * makes use of local variables.
          * It provides a reasonable number of formal parameters.
          */
        private static void impl_tasklet_callback(TaskletCallback y,
                                                  Object? obj1,
                                                  Object? obj2,
                                                  Object? obj3,
                                                  Object? obj4) throws Error
        {
            y(obj1, obj2, obj3, obj4);
        }

        private static void * helper_tasklet_callback(void *v) throws Error
        {
            struct_helper_tasklet_callback *tuple_p =
                    (struct_helper_tasklet_callback *)v;
            // The caller function has to add a reference to the ref-counted instances
            TaskletCallback y_save = tuple_p->y;
            Object? obj1_save = tuple_p->obj1;
            Object? obj2_save = tuple_p->obj2;
            Object? obj3_save = tuple_p->obj3;
            Object? obj4_save = tuple_p->obj4;
            // schedule back to the spawner; this will probably invalidate *v and *tuple_p.
            Tasklet.schedule_back();
            // The actual call
            impl_tasklet_callback(y_save,
                                  obj1_save,
                                  obj2_save,
                                  obj3_save,
                                  obj4_save);
            // void method, return null
            return null;
        }

        public static Tasklet tasklet_callback(TaskletCallback y,
                                            Object? obj1=null,
                                            Object? obj2=null,
                                            Object? obj3=null,
                                            Object? obj4=null,
                                            bool joinable=false)
        {
            struct_helper_tasklet_callback arg = 
                    struct_helper_tasklet_callback();
            arg.y = y;
            arg.obj1 = obj1;
            arg.obj2 = obj2;
            arg.obj3 = obj3;
            arg.obj4 = obj4;
            return Tasklet.spawn((Spawnable)helper_tasklet_callback, &arg, joinable);
        }

        public static bool nap_until_condition(
                ConditionFunc condition_func,
                int total_msec,
                int period_usec=2000)
        {
            Timer t = new Timer(total_msec);
            bool ret = false;
            while (! t.is_expired())
            {
                if (condition_func())
                {
                    ret = true;
                    break;
                }
                Tasklet.nap(0, period_usec);
            }
            if (! ret) ret = condition_func();
            return ret;
        }
    }
}

