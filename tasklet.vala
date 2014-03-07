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
using Wrapped.LibPth;

namespace Tasklets
{
#if log_tasklet
    private string tasklet_id()
    {
        return @"[$(Tasklet.self().id)] ";
    }
#else
    private string tasklet_id()
    {
        return "";
    }
#endif
    internal void log_debug(string msg)     {Posix.syslog(Posix.LOG_DEBUG,
                    tasklet_id() + " DEBUG "  + msg);}
    internal void log_info(string msg)      {Posix.syslog(Posix.LOG_INFO,
                    tasklet_id() + " INFO "   + msg);}
    internal void log_notice(string msg)    {Posix.syslog(Posix.LOG_NOTICE,
                    tasklet_id() + " INFO+ "  + msg);}
    internal void log_warn(string msg)      {Posix.syslog(Posix.LOG_WARNING,
                    tasklet_id() + " INFO++ " + msg);}
    internal void log_error(string msg)     {Posix.syslog(Posix.LOG_ERR,
                    tasklet_id() + " ERROR "  + msg);}
    internal void log_critical(string msg)  {Posix.syslog(Posix.LOG_CRIT,
                    tasklet_id() + " ERROR+ " + msg);}

    public delegate void TaskletCallback(Object? obj1, Object? obj2, Object? obj3, Object? obj4) throws Error;

    struct struct_helper_tasklet_callback
    {
        public TaskletCallback y;
        public Object? obj1;
        public Object? obj2;
        public Object? obj3;
        public Object? obj4;
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
    public class Tasklet : Object
    {
        public static void tasklet_leaves(string reason="")
        {
#if log_tasklet_switch
            Tasklets.log_debug(@"Tasklet $(self().id) gives yield ($(reason)).");
#else
#endif
        }
        public static void tasklet_regains(string reason="")
        {
#if log_tasklet_switch
            Tasklets.log_debug(@"Tasklet $(self().id) gains back control ($(reason)).");
#else
#endif
        }

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
                _next = next.pth;
            Tasklet.tasklet_leaves();
            /*int retval =*/ PthThread.pth_yield(_next);
            // TODO if (retval == 0) throw new;
            Tasklet.tasklet_regains();
        }

        public static void schedule_back()
        {
            schedule(last_scheduling_tasklet);
        }

        public static Tasklet self()
        {
            PthThread self_pth_thread = PthThread.self();
            uint hash_self_pth_thread = PthThread.hash_func(self_pth_thread);
            Tasklet ret = tasklets[self_pth_thread];
            return ret;
        }
        
        public static void nap(long sec, long usec)
        {
            Tasklet.tasklet_leaves("with nap");
            PthThread.nap(sec, usec);
            Tasklet.tasklet_regains("from nap");
        }

        public static int system(string? command)
        {
            Tasklet.tasklet_leaves("with system");
            int ret = PthThread.system(command);
            Tasklet.tasklet_regains("from system");
            return ret;
        }

        private static int next_id;
        private int my_id;
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

        public static Tasklet spawn(FunctionDelegate function, void *params_tuple_p, bool joinable=false, int stacksize=-1)
        {
            // alloc in heap the tasklet_function_params_tuple
            tasklet_function_params_tuple *function_params_tuple_p = malloc(sizeof(tasklet_function_params_tuple));
            // point to params_tuple from the tasklet_function_params_tuple
            function_params_tuple_p->function = function;
            function_params_tuple_p->params_tuple_p = params_tuple_p;
            // spawn
            Tasklet retval = new Tasklet();
            if (stacksize > 0)
            {
                Attribute attr = new Attribute();
                attr.set_stacksize(stacksize);
                retval.pth = PthThread.spawn(attr, (FunctionDelegate)tasklet_marshaller, function_params_tuple_p);
            }
            else
            {
                Attribute attr = new Attribute();
                attr.set_stacksize(1024 * _default_thread_stack_size);
                retval.pth = PthThread.spawn(attr, (FunctionDelegate)tasklet_marshaller, function_params_tuple_p);
            }
            if (! joinable) retval.pth.set_joinable(joinable);
            tasklets[retval.pth] = retval;
            // Immediately schedule the helper_xxx function in order to do copies and/or refcounting.
            //  (see testsuite microfunc_tester_1.vala for an example)
            schedule(retval);
            // The helper_xxx function should pass the schedule back to me afterwards.
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
            public FunctionDelegate function;
            public void *params_tuple_p;
        }

        private static void *tasklet_marshaller(void *v)
        {
            void *result = null;
            try
            {
                tasklet_function_params_tuple *function_params_tuple_p = (tasklet_function_params_tuple *)v;
                result = function_params_tuple_p->function(function_params_tuple_p->params_tuple_p);
                free(v);
            }
            catch (Error e)
            {
                Tasklets.log_warn(@"a microfunc reported an error: $(e.message)");
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
            Object? obj3_save = tuple_p->obj1;
            Object? obj4_save = tuple_p->obj2;
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

        public static void tasklet_callback(TaskletCallback y,
                                            Object? obj1=null,
                                            Object? obj2=null,
                                            Object? obj3=null,
                                            Object? obj4=null)
        {
            struct_helper_tasklet_callback arg = 
                    struct_helper_tasklet_callback();
            arg.y = y;
            arg.obj1 = obj1;
            arg.obj2 = obj2;
            arg.obj3 = obj3;
            arg.obj4 = obj4;
            Tasklet.spawn((FunctionDelegate)helper_tasklet_callback, &arg);
        }
    }
}

