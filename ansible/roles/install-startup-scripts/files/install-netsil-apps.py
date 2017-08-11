import httplib
import json
import time
import os
import argparse

MARATHON_HOST = os.environ.get('MARATHON_HOST', failobj='marathon.mesos')
MARATHON_PORT = os.environ.get('MARATHON_PORT', failobj='8080')
MESOS_HOST = os.environ.get('MESOS_HOST', failobj='leader.mesos')
MESOS_PORT = os.environ.get('MESOS_PORT', failobj='5050')
APPS_DIR = os.environ.get('APPS_DIR', failobj='/opt/netsil/latest/apps/build/specs')
BUILD_TYPE = os.environ.get('BUILD_TYPE', failobj='cloud')

exclude_in_cloud = ['ceph-osd', 'ceph-rgw', 'ceph-monitor', 'druid-realtime']
exclude_in_singlenode = ['druid-middle-manager', 'tranquility']

def wait(count, step, timeout):
    time.sleep(step)
    count += step
    if count > timeout:
        print "Timeout exceeded! exiting installation process"
        exit(1)
    else:
        print "Waiting for " + str(count) + " of " + str(timeout) + " seconds. Timeout not yet reached."
    return count

def wait_for_marathon():
    timeout=1800
    count=0
    step=10
    while True:
        try:
            conn = httplib.HTTPConnection(MARATHON_HOST + ':' + MARATHON_PORT)
            conn.request('GET', '/v2/apps')
            resp = conn.getresponse()
            status = resp.status
            if status == 200:
                print "Marathon is initialized. Proceeding to install apps!"
                break
            else:
                print "Waiting for marathon to initialize..."
                count = wait(count, step, timeout)
        except:
            print "Could not connect to marathon..."
            count = wait(count, step, timeout)

def get_total_workers():
    timeout=1800
    count=0
    step=10
    while True:
        try:
            conn = httplib.HTTPConnection(MESOS_HOST + ':' + MESOS_PORT)
            conn.request('GET', '/metrics/snapshot')
            resp = conn.getresponse()
            respBody = resp.read()
            respObj = json.loads(respBody)
            total_workers = int(respObj['master/slaves_active'])
            print "Total workers is: " + str(total_workers)
            return total_workers
        except:
            print "Could not connect to marathon..."
            count = wait(count, step, timeout)

def do_scale(app_json):
    if 'env' in app_json:
        app_env = app_json['env']
        return 'DO_SCALE' in app_env and app_env['DO_SCALE'] == 'yes'
    else:
        return False

def filter_apps(all_apps, filter_list):
    for app in filter_list:
        app_file = app + '.json'
        if app_file in all_apps:
            all_apps.remove(app_file)
    return all_apps

def list_apps():
    all_apps = os.listdir(APPS_DIR)
    if BUILD_TYPE == 'cloud':
        return filter_apps(all_apps, exclude_in_cloud)
    else:
        return filter_apps(all_apps, exclude_in_singlenode)

def scale_netsil_apps():
    total_workers = get_total_workers()
    scale_json = {'instances': total_workers}
    for app in list_apps():
        with open(APPS_DIR + '/' + app, 'rb') as app_file:
            app_json = json.load(app_file)
            if 'id' in app_json and do_scale(app_json):
                app_id = app_json['id']
                conn = httplib.HTTPConnection(MARATHON_HOST + ':' + MARATHON_PORT)
                conn.request('PUT', '/v2/apps/' + str(app_id), json.dumps(scale_json), {"Content-type": "application/json"})
                resp = conn.getresponse()
                status = resp.status
                if status == 200:
            	    print "Scaled app!"
                else:
                    print "Issue scaling app: " + str(app_id)
                    exit(1)

# Solely to get past the wait-time
def restart_app(app_id):
    timeout=1800
    count=0
    step=10
    while True:
        try:
            conn = httplib.HTTPConnection(MARATHON_HOST + ':' + MARATHON_PORT)
            conn.request('POST', '/v2/apps/' + str(app_id) + '/restart')
            resp = conn.getresponse()
            status = resp.status
            if status == 200:
                print "Restarted app!"
                break
            else:
                print "Waiting for marathon to initialize..."
                count = wait(count, step, timeout)
        except:
            print "Could not connect to marathon..."
            count = wait(count, step, timeout)

def install_netsil_apps():
    for app in list_apps():
        with open(APPS_DIR + '/' + app, 'rb') as app_file:
            app_json = json.load(app_file)
            if 'id' in app_json:
                app_id = app_json['id']
            else:
                print "Error! No app id in json file."
                exit(1)
            conn = httplib.HTTPConnection(MARATHON_HOST + ':' + MARATHON_PORT)
            conn.request('POST', '/v2/apps', json.dumps(app_json), {"Content-type": "application/json"})
            resp = conn.getresponse()
            status = resp.status
            if status == 201:
                print "Installed app: " + str(app_id)
            elif status == 409:
                print "Warning! App with ID " + str(app_id) + " already exists!"
                # restart_app(app_id)
            else:
                print "Error: Return code " + str(status) + " not recognized."
                print "Error: " + str(resp.read())
                exit(1)
def wait_for_deployments():
    pass

def main(action):
    wait_for_marathon()
    if action == 'install':
        install_netsil_apps()
    elif action == 'scale':
        wait_for_deployments()
        scale_netsil_apps()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='install action')
    parser.add_argument('-a', '--action', default='install', dest='action', type=str, nargs='?')
    args = parser.parse_args()
    main(args.action)

