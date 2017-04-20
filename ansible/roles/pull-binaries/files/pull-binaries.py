import json
import os
import subprocess

PWD = os.environ.get('PWD', failobj='/root')
APPS_DIR = os.environ.get('APPS_DIR', failobj='/opt/netsil/latest/apps/build/specs')
REGISTRY= os.environ.get('REGISTRY', failobj='')

for app in os.listdir(APPS_DIR):
    with open(APPS_DIR + '/' + app, 'rb') as app_file:
        app_json = json.load(app_file)
        try:
            image = app_json['container']['docker']['image']
        except Exception as e:
            print "Error getting image from " + str(app_file) + ": " + str(e)
        offline_image = image.split('/')[-1] + ".tar.gz"
        if os.path.isfile(PWD + '/image/' + offline_image):
            print "Pulling local image " + image + " from filesystem"
            cmd = "docker load < "  + PWD + "/images/" + offline_image
            subprocess.Popen(cmd, shell=True, executable='/bin/bash')
        else:
            registry_prefix = REGISTRY + '/' if REGISTRY else ""
            print "Pulling image " + registry_prefix + image + " from registry "
            cmd = "docker pull "  + registry_prefix + image
            subprocess.Popen(cmd, shell=True, executable='/bin/bash')

