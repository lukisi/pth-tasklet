using Ntk.Lib;
using Ntk.Lib.TaskletUtils;

void main(string[] args)
{
    LoggerInit();
    LoggerFilePath = "/tmp/bcast.log";
    Tasklet.init(64);
    if ("bcastsend" in args[0])
    {
        string dev = args[1];
        stdout.printf(@"Sending to $dev.\n");
        var s = new BroadcastClientDatagramSocket(dev, 269);
        uchar[] mesg = {'a','b','c','d'};
        s.send(mesg);
        s.close();
    }
    else if ("bcastlisten" in args[0])
    {
        string dev = args[1];
        stdout.printf(@"Listening to $dev.\n");
        var listen_s = new ServerDatagramSocket(269, null, dev);
        string rmt_ip;
        uint16 rmt_port;
        uchar[] message = listen_s.recvfrom(8192, out rmt_ip, out rmt_port);
        stdout.printf(@"$(message.length) bytes from $(rmt_ip):$(rmt_port).\n");
        listen_s.close();
    }
}
