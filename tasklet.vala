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
    [CCode (has_target = false)]
    public delegate void * Spawnable (void* user_data) throws Error;

#if log_tasklet
    private string tasklet_id()
    {
        string ret = @"$(Tasklet.self().id)";
        int len = ret.length;
        for (int i = 0; i < 5-len; i++) ret = " " + ret;
        return @"[$(ret)] ";
    }
#else
    private string tasklet_id()
    {
        return "";
    }
#endif
    internal void log_debug(string msg)     {Posix.syslog(Posix.LOG_DEBUG,
                    tasklet_id() + "DEBUG "  + msg);}
    internal void log_info(string msg)      {Posix.syslog(Posix.LOG_INFO,
                    tasklet_id() + "INFO "   + msg);}
    internal void log_notice(string msg)    {Posix.syslog(Posix.LOG_NOTICE,
                    tasklet_id() + "INFO+ "  + msg);}
    internal void log_warn(string msg)      {Posix.syslog(Posix.LOG_WARNING,
                    tasklet_id() + "INFO++ " + msg);}
    internal void log_error(string msg)     {Posix.syslog(Posix.LOG_ERR,
                    tasklet_id() + "ERROR "  + msg);}
    internal void log_critical(string msg)  {Posix.syslog(Posix.LOG_CRIT,
                    tasklet_id() + "ERROR+ " + msg);}

    public delegate void TaskletCallback(Object? obj1, Object? obj2, Object? obj3, Object? obj4) throws Error;
    public delegate bool ConditionFunc();

    struct struct_helper_tasklet_callback
    {
        public TaskletCallback y;
        public Object? obj1;
        public Object? obj2;
        public Object? obj3;
        public Object? obj4;
    }

    /** Set of methods to help monitoring the tasklets.
      *
      * When the tasklet system is initiated, the program can provide callbacks
      * in order to control the type of object that maintain the data.
      * For instance, the object Stat has data for the id of tasklet and its
      * spawner and the funcname (as it can be reported by using the method
      * declare_self). The program could provide a subclass that can contain
      * the time of starting and ending of the tasklet.
      */
    public class Stat : Object
    {
        public int id;
        public int parent;
        public string funcname = "";
        public Status status;
        public string crash_message = "";

        // logs
        private int next_log_pos = 0;
        private LinkedList<StatLog> mylogs;
        private void init_logs()
        {
            if (mylogs == null)
            {
                mylogs = new LinkedList<StatLog>();
            }
        }
        private void expunge_logs()
        {
            while (true)
            {
                if (mylogs.is_empty) break;
                if (mylogs[0].tm.is_expired()) mylogs.remove_at(0);
                else break;
            }
        }
        public void log(string msg)
        {
            init_logs();
            expunge_logs();
            StatLog log = new StatLog();
            log.pos = next_log_pos++;
            log.msg = msg;
            log.tm = new Timer(1000);
            mylogs.add(log);
        }
        public ArrayList<string> get_logs()
        {
            init_logs();
            expunge_logs();
            ArrayList<string> ret = new ArrayList<string>();
            if (! mylogs.is_empty)
            {
                // first item is the pos of first log
                ret.add(@"$(mylogs[0].pos)");
                foreach (StatLog log in mylogs)
                {
                    ret.add(log.msg);
                }
            }
            return ret;
        }

        public static bool equal_func(Stat a, Stat b)
        {
            return a.id == b.id;
        }
    }

    public class StatLog : Object
    {
        public int pos;
        public string msg;
        public Timer tm;
    }

    public enum EventType {
        STARTED,
        ENDED,
        CRASHED,
        ABORTED
    }

    public enum Status {
        SPAWNED,
        STARTED,
        ENDED,
        CRASHED,
        ABORTED
    }

    public delegate Stat CreateTaskletStat();
    public delegate void TaskletEvent(Stat tasklet, EventType event_type);

    private CreateTaskletStat? create_tasklet_stat_func=null;
    private TaskletEvent? tasklet_event_func=null;
    private HashMap<int, Stat>? tasklet_stats=null;

    public void
    init_stats
    (CreateTaskletStat? _create_tasklet_stat_func=null,
     TaskletEvent? _tasklet_event_func=null)
    {
        create_tasklet_stat_func = () => {return new Stat();};
        tasklet_event_func = (tasklet, event_type) => {};
        if (_create_tasklet_stat_func != null)
            create_tasklet_stat_func = _create_tasklet_stat_func;
        if (_tasklet_event_func != null)
            tasklet_event_func = _tasklet_event_func;
        tasklet_stats = new HashMap<int, Stat>();
    }

    /** get all statistics
     */
    public ArrayList<Stat>? get_tasklet_stats()
    {
        if (tasklet_stats == null) return null;
        ArrayList<Stat> ret =
                new ArrayList<Stat>(Stat.equal_func);
        ret.add_all(tasklet_stats.values);
        return ret;
    }

    /** remove some statistics
     */
    public void purge_tasklet_stats(Gee.List<int> ids)
    {
        foreach (int id in ids) tasklet_stats.unset(id);
    }

    /** get my statistics
     */
    private Stat self_tasklet_stats()
    {
        return tasklet_stats[Tasklet.self().id];
    }

    /** use my statistics for logging
     */
    private void self_log(string msg)
    {
        self_tasklet_stats().log(msg);
    }

    /** get recent logs for a given tasklet (id)
     */
    private ArrayList<string> get_logs(int id)
    {
        Stat s = tasklet_stats[id];
        return s.get_logs();
    }

    /** data for function exec_command.
      */

    char[] cmdout_buf = null;
    char[] cmderr_buf = null;
    const int buf_size = 20000;

    public class CommandResult : Object
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
            {
                _next = next.pth;
            }
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

        public static void declare_self(string fname)
        {
            if (tasklet_stats != null)
            {
                int self_id = self().id;
                Stat st = tasklet_stats[self_id];
                if (st.funcname != "") st.funcname += " => ";
                st.funcname += fname;
            }
        }

        public static void declare_finished(string fname)
        {
            if (tasklet_stats != null)
            {
                int self_id = self().id;
                Stat st = tasklet_stats[self_id];
                string toremove = " => " + fname;
                if (st.funcname.length > toremove.length &&
                    st.funcname.substring(st.funcname.length - toremove.length) == toremove)
                    st.funcname = st.funcname.substring(0, st.funcname.length - toremove.length);
            }
        }

        /** use my tasklet for logging
         */
        public static void self_log(string msg)
        {
            Tasklets.self_log(msg);
        }

        /** get recent logs for a given tasklet (id)
         */
        public static ArrayList<string> get_logs(int id)
        {
            return Tasklets.get_logs(id);
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

        /** Launch a process and block this tasklet till it ends.
          * Returns exit status, stdout and stderr.
          */
        public static CommandResult exec_command(string cmdline) throws SpawnError
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
            Process.spawn_async_with_pipes(null, cmdline.split(" "), null,
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
                log_warn(@"Tasklet: process '$(cmdline)' failed with errno = $(Posix.errno).");
                com_ret.exit_status = -1;
            }
            else if (Process.if_exited(waitpid_status))
            {
                com_ret.exit_status = Process.exit_status(waitpid_status);
            }
            else if (Process.if_signaled(waitpid_status))
            {
                log_info(@"Tasklet: process '$(cmdline)' was terminated by a signal");
                com_ret.exit_status = (int)Process.term_sig(waitpid_status);
            }
            else if (Process.if_stopped(waitpid_status))
            {
                log_info(@"Tasklet: process '$(cmdline)' was _stopped_ by a signal");
                com_ret.exit_status = (int)Process.stop_sig(waitpid_status);
            }
            else if (Process.core_dump(waitpid_status))
            {
                log_warn(@"Tasklet: process '$(cmdline)' core dumped.");
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
            if (tasklet_stats != null)
            {
                tasklet_stats[retval.id] = create_tasklet_stat_func();
                tasklet_stats[retval.id].id = retval.id;
                tasklet_stats[retval.id].parent = self().id;
                tasklet_stats[retval.id].status = Status.SPAWNED;
            }
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
            if (tasklet_stats != null)
            {
                tasklet_stats[id].status = Status.ABORTED;
                tasklet_event_func(tasklet_stats[id], EventType.ABORTED);
            }
            pth.abort();
        }

        private struct tasklet_function_params_tuple
        {
            public Spawnable function;
            public void *params_tuple_p;
        }

        private static void *tasklet_marshaller(void *v)
        {
            int self_id = self().id;
            void *result = null;
            try
            {
                tasklet_function_params_tuple *function_params_tuple_p = (tasklet_function_params_tuple *)v;
                if (tasklet_stats != null)
                {
                    tasklet_stats[self_id].status = Status.STARTED;
                    tasklet_event_func(tasklet_stats[self_id], EventType.STARTED);
                }
                result = function_params_tuple_p->function(function_params_tuple_p->params_tuple_p);
            }
            catch (Error e)
            {
                Tasklets.log_warn(@"a microfunc reported an error: $(e.message)");
                if (tasklet_stats != null)
                {
                    tasklet_stats[self_id].status = Status.CRASHED;
                    tasklet_stats[self_id].crash_message = e.message;
                    tasklet_event_func(tasklet_stats[self_id], EventType.CRASHED);
                }
            }
            if (tasklet_stats != null && tasklet_stats[self_id].status != Status.CRASHED)
            {
                tasklet_stats[self_id].status = Status.ENDED;
                tasklet_event_func(tasklet_stats[self_id], EventType.ENDED);
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
                                            Object? obj4=null)
        {
            struct_helper_tasklet_callback arg = 
                    struct_helper_tasklet_callback();
            arg.y = y;
            arg.obj1 = obj1;
            arg.obj2 = obj2;
            arg.obj3 = obj3;
            arg.obj4 = obj4;
            return Tasklet.spawn((Spawnable)helper_tasklet_callback, &arg);
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

