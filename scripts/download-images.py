import os
import errno
import json
import subprocess
import argparse
from os import makedirs, path

PWD = os.environ.get('PWD', failobj='/tmp')

images = list()

def mkdir_p(path):
    try:
        makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

def main(apps_dir, images_dir, action):
    # Get list of images
    specs_dir = apps_dir + '/build/specs'
    if os.path.isdir(specs_dir):
        for app in os.listdir(specs_dir):
            with open(specs_dir + '/' + app, 'r') as app_file:
                app_json = json.load(app_file)
                try:
                    image = app_json['container']['docker']['image']
                    images.append(image)
                except Exception as e:
                    print "Error getting image from " + str(app_file) + ": " + str(e)
                    exit(1)
    else:
        print "Error! Your apps directory " + str(apps_dir) + " was not valid!"
        exit(1)

    # Print and exit, if directed.
    if action == 'print':
        for image in images:
            print image
        exit(0)

    # Pull images
    pull_processes = list()
    for image in images:
        print "Pulling image " + image
        cmd = "docker pull "  + image
        p = subprocess.Popen(cmd.split(),
                                shell=False,
                                preexec_fn=os.setpgrp)
        pull_processes.append(p)

    for p in pull_processes:
        p.wait()

    # Save images (optional)
    if action == 'save':
        # Create directories if not found
        mkdir_p(images_dir)

        save_processes = list()
        for image in images:
            print "Saving image " + image
            offline_image = image.split('/')[-1] + ".tar.gz"
            cmd = "docker save " + image + " > " + images_dir + "/" + offline_image
            p = subprocess.Popen(cmd,
                                shell=True,
                                preexec_fn=os.setpgrp)
            save_processes.append(p)

        for p in save_processes:
            p.wait()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='For downloading images')
    parser.add_argument('-a', '--apps-dir', default=PWD + '/apps', dest='apps_dir', type=str, nargs='?')
    parser.add_argument('-i', '--images-dir', default=PWD + '/images', dest='images_dir', type=str, nargs='?')
    parser.add_argument('action', nargs='?')
    args, leftovers = parser.parse_known_args()
    main(args.apps_dir, args.images_dir, args.action)
