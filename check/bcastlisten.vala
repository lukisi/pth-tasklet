using Ntk.Lib;
using Ntk.Lib.TaskletUtils;

void main(string[] args)
{
    if ("bcastsend" in args[0])
    {
        string dev = args[1];
        stdout.printf(@"Sending to $dev.\n");
    }
    else if ("bcastlisten" in args[0])
    {
        string dev = args[1];
        stdout.printf(@"Listening to $dev.\n");
    }
}
