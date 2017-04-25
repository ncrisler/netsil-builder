import json
import os
import subprocess

PWD = os.environ.get('PWD', failobj='/root')
APPS_DIR = os.environ.get('APPS_DIR', failobj='/opt/netsil/latest/apps/build/specs')

processes = list()
for app in os.listdir(APPS_DIR):
    with open(APPS_DIR + '/' + app, 'rb') as app_file:
        app_json = json.load(app_file)
        try:
            image = app_json['container']['docker']['image']
            offline_image = image.split('/')[-1] + ".tar.gz"
        except Exception as e:
            print "Error getting image from " + str(app_file) + ": " + str(e)
            exit(1)

        if os.path.isfile(PWD + '/image/' + offline_image):
            print "Pulling local image " + image + " from filesystem"
            cmd = "docker load < "  + PWD + "/images/" + offline_image
            p = subprocess.Popen(cmd, shell=True, executable='/bin/bash')
            processes.append(p)
        else:
            print "Pulling image " + image
            cmd = "docker pull "  + image
            p = subprocess.Popen(cmd.split(),
                                 shell=False,
                                 preexec_fn=os.setpgrp)
            processes.append(p)

# Wait for processes to finish
for p in processes:
    p.wait()
