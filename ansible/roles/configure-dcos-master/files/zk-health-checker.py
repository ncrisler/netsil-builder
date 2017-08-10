import subprocess
import time
from os import listdir
from os.path import isfile, join, getsize

connection_port = 2181
zk_pid_path = '/var/lib/zookeeper/snapshot/zookeeper_server.pid'
zk_log_dir = '/var/lib/zookeeper/transactions/version-2'

def exec_shell_command(command):
    proc = subprocess.Popen(command.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    return out, err, proc.returncode

def main():
    sleep_time = 300
    while True:
        time.sleep(sleep_time)
        out, err, returncode = exec_shell_command('netstat -tulpna')

        num_connections = 0
        found_port = False
        for line in out.splitlines():
            fields = line.split()

            # get rid of unnecessary lines
            if len(fields) != 7:
                continue

            # get necessary fields
            protocol = fields[0]
            local_address = fields[3]
            foreign_address = fields[4]
            state = fields[5]

            # we are interested in listening tcp sockets
            if protocol[0:3] != 'tcp' or state != 'LISTEN':
                continue

            # Check the zk port
            port = ':' + str(connection_port)
            if local_address.endswith(port):
                found_port = True

        if found_port:
            print "Zk port is listening"
            # Reducing sleep time back to normal in case it was increased
            sleep_time = 300
        else:
            print "Zk port is not listening! Attempting repair..."

            print "Removing pid file"
            exec_shell_command('rm -f ' + zk_pid_path)

            print "Removing any empty log files"
            logfiles = [join(zk_log_dir, f) for f in listdir(zk_log_dir) if isfile(join(zk_log_dir, f)) and f.startswith("log")]
            print "Found logfiles: " + str(logfiles)
            for logfile in logfiles:
                if getsize(logfile) == 0:
                    print "File size of " + logfile + " is zero. Removing."
                    exec_shell_command('rm -f ' + logfile)

            # Increasing sleep time so zk has time to start
            sleep_time = 600

if __name__ == '__main__':
    print "Started zk-health-checker!"
    main()
