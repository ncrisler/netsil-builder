
cd /opt/netsil/latest/apps/build/specs
for app in *.json
do
    # Pull docker images
    image=$(jq --raw-output < ${app} 'select(.container.docker.image != null) .container.docker.image')
    if [[ -n ${image} ]] ; then
        image_filename=$(echo $image | cut -d\/ -f2).tar.gz
        if [ -f "{{ ansible_env.PWD }}/images/$image_filename" ]; then
            echo "Pulling local image ${image} from filesystem"
            docker load < "{{ ansible_env.PWD }}/images/$image_filename"
        else
            {% if registry %}
                echo "Pulling image ${image} from {{ registry }}"
                docker pull "{{ registry }}/"${image}
            {% else %}
                echo "Pulling image ${image} from Dockerhub"
                docker pull ${image}
            {% endif %}
            if [[ $? != 0 ]] ; then
                echo "Docker pull failed. Exiting build."
                exit 1
            fi
        fi
    fi
done
