using PthTasklet;

public class Tester : Object
{
    public int a;

    public void operation_alpha()
    {
        // this will be called in a new tasklet
        print(@"Tasklet $(Tasklet.self().id) operation_alpha\n");
    }

    public void operation_beta()
    {
        // this will be called directly.
        int x = 23;
        // now spawn a tasklet and acts on member of this
        Tasklet.tasklet_callback(
            () => {
                print(@"Tasklet $(Tasklet.self().id) a = $(a)\n");
            });
        // now spawn a tasklet and acts on local variable
        x = 34;
        Tasklet.tasklet_callback(
            () => {
                print(@"Tasklet $(Tasklet.self().id) local x = $(x)\n");
            });
        x = 35;
        /*   This would segfault!
        // now spawn a tasklet and acts on local Object
        Tester i = new Tester();
        i.a = 123;
        Tasklet.tasklet_callback(
            () => {
                print(@"Tasklet $(Tasklet.self().id) local object i, i.a = $(i.a)\n");
            });
        */
        // now spawn a tasklet and effectively pass a local Object
        Tester i = new Tester();
        i.a = 123;
        Tasklet.tasklet_callback(
            (tpar1) => {
                Tester tasklet_i = (Tester)tpar1;
                print(@"Tasklet $(Tasklet.self().id) local object i passed, i.a = $(tasklet_i.a)\n");
            },
            i);
    }
}

void main(string[] args)
{
    Tasklet.init();
    var t = new Tester();
    t.a = 1;
    Tasklet.tasklet_callback(t.operation_alpha);
    t.operation_beta();
    print(@"Tasklet $(Tasklet.self().id) going to sleep\n");
    Tasklet.nap(1, 0);
    Tasklet.kill();
}
