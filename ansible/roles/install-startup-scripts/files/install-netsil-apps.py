import httplib
import json
import time
import os

MARATHON_HOST = os.environ.get('MARATHON_HOST', failobj='marathon.mesos')
MARATHON_PORT = os.environ.get('MARATHON_PORT', failobj='8080')
APPS_DIR = os.environ.get('APPS_DIR', failobj='/opt/netsil/latest/apps/build/specs')

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

# Solely to get past the wait-time
def install_app(app_id, app_json):
    timeout=1800
    count=0
    step=10
    while True:
        try:
            # Make install request
            conn = httplib.HTTPConnection(MARATHON_HOST + ':' + MARATHON_PORT)
            conn.request('POST', '/v2/apps', json.dumps(app_json), {"Content-type": "application/json"})
            resp = conn.getresponse()
            status = resp.status

            if status == 201 or status == 200:
                print "Installed app: " + str(app_id)
                break
            elif status == 409:
                print "Warning! App with ID " + str(app_id) + " already exists!"
                restart_app(app_id)
                break
            elif status == 503:
                print "Got a return code of 503. Retrying request."
                count = wait(count, step, timeout)
            else:
                print "Error: Return code " + str(status) + " not recognized."
                print "Error: " + str(resp.read())
                exit(1)
        except:
            print "Could not connect to marathon..."
            count = wait(count, step, timeout)

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

def restart_netsil_apps():
    apps = get_current_apps()
    for app in apps:
        app_id = app['id']
        restart_app(app_id)

def install_netsil_apps():
    for app in os.listdir(APPS_DIR):
        with open(APPS_DIR + '/' + app, 'rb') as app_file:
            app_json = json.load(app_file)
            app_id = app_json['id']
            install_app(app_id, app_json):

def get_current_apps():
    try:
        conn = httplib.HTTPConnection(MARATHON_HOST + ':' + MARATHON_PORT)
        conn.request('GET', '/v2/apps')
        resp = conn.getresponse()
        body = resp.read()
        apps_data = json.loads(body)
        return apps_data['apps']
    except:
        print "Could not contact marathon!"
        exit(1)

def first_time_install():
    return not get_current_apps()

def main():
    wait_for_marathon()

    # Install apps only if there aren't any marathon apps
    if first_time_install():
        install_netsil_apps()
    else:
        restart_netsil_apps()

if __name__ == '__main__':
    main()
