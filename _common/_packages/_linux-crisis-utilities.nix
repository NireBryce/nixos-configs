{ pkgs, ...}:

# These are crisis tools, as mentioned in https://www.brendangregg.com/blog/2024-03-24/linux-crisis-tools.html
# who makes the case for these being installed on every system.  While I don't need them, I like being in the habit.
{

  environment.systemPackages = with pkgs; [
    procps     # ps(1), uptime(1), vmstat(8)      | basic stats
    util-linux # dmesg(1), lsblk(1), lscpu(1)     | system log, device info
    sysstat    # iostat(1), mpstat(1), etc        | device stats
    iproute2   #  ip(8), ss(8), nstat(8), tc(8)   | preferred net tools
    numactl    # numastat(8)                      | NUMA stats
    tcpdump    # tcpdump(8)                       | Network sniffer
    bcc        # hardirqs(8), funccount(8) etc    | canned eBPF tools 
    bpftrace   # bpftrace, basic bcc tools        | eBPF scripting
    trace-cmd  # trace-cmd(1)                     | Ftrace CLI
    ethtool    # ethtool(8)                       | net device info
    tiptop     # tiptop(1)                        | PMU/PMC top
    cpuid      # cpuid(1)                         | CPU details
    msr-tools  # rdmsr(8), wrmsr(8)               | CPU digging
    
    # TODO: find package name 
    # linux-tools-common # perf(1), turbostat(8)  | profiler and PMU stats    
    # nicstat            # nicstat(1)             | net device stats
  ];
  

  
}
# https://www.brendangregg.com/blog/2024-03-24/linux-crisis-tools.html
# > Can't I just install them later when needed?
# >
# > Many problems can occur when trying to install software during a production crisis. I'll step through a made-up example that combines some of the things I've learned the hard way:
# >
# >    4:00pm: Alert! Your company's site goes down. No, some people say it's still up. Is it up? It's up but too slow to be usable.
# >    4:01pm: You look at your monitoring dashboards and a group of backend servers are abnormal. Is that high disk I/O? What's causing that?
# >    4:02pm: You SSH to one server to dig deeper, but SSH takes forever to login.
# >    4:03pm: You get a login prompt and type "iostat -xz 1" for basic disk stats to begin with. There is a long pause, and finally "Command 'iostat' not found...Try: sudo apt install sysstat". Ugh. Given how slow the system is, installing this package could take several minutes. You run the install command.
# >    4:07pm: The package install has failed as it can't resolve the repositories. Something is wrong with the /etc/apt configuration. Since the server owners are now in the SRE chatroom to help with the outage, you ask: "how do you install system packages?" They respond "We never do. We only update our app." Ugh. You find a different server and copy its working /etc/apt config over.
# >    4:10pm: You need to run "apt-get update" first with the fixed config, but it's miserably slow.
# >    4:12pm: ...should it really be taking this long??
# >    4:13pm: apt returned "failed: Connection timed out." Maybe this system is too slow with the performance issue? Or can't it connect to the repos? You begin network debugging and ask the server team: "Do you use a firewall?" They say they don't know, ask the network security team.
# >    4:17pm: The network security team have responded: Yes, they have blocked any unexpected traffic, including HTTP/HTTPS/FTP outbound apt requests. Gah. "Can you edit the rules right now?" "It's not that easy." "What about turning off the firewall completely?" "Uh, in an emergency, sure."
# >    4:20pm: The firewall is disabled. You run apt-get update again. It's slow, but works! Then apt-get install, and...permission errors. What!? I'm root, this makes no sense. You share your error in the SRE chatroom and someone points out: Didn't the platform security team make the system immutable?
# >    4:24pm: The platform security team are now in the SRE chatroom explaining that some parts of the file system can be written to, but others, especially for executable binaries, are blocked. Gah! "How do we disable this?" "You can't, that's the point. You'd have to create new server images with it disabled."
# >    4:27pm: By now the SRE team has announced a major outage and informed the executive team, who want regular status updates and an ETA for when it will be fixed. Status: Haven't done much yet.
# >    4:30pm: You start running "cat /proc/diskstats" as a rudimentary iostat(1), but have to spend time reading the Linux source (admin-guide/iostats.rst) to make sense of it. It just confirms the disks are busy which you knew anyway from the monitoring dashboard. You really need the disk and file system tracing tools, like biosnoop(8), but you can't install them either. Unless you can hack up rudimentary tracing tools as well...You "cd /sys/kernel/debug/tracing" and start looking for the FTrace docs.
# >    4:55pm: New server images finally launch with all writable file systems. You login – gee it's fast – and "apt-get install sysstat". Before you can even run iostat there are messages in the chatroom: "Website's back up! Thanks! What did you do?" "We restarted the servers but we haven't fixed anything yet." You have the feeling that the outage will return exactly 10 minutes after you've fallen asleep tonight.
# >    12:50am: Ping! I knew this would happen. You get out of bed and open your work laptop. The site is down – it's been hacked – someone disabled the firewall and file system security.
