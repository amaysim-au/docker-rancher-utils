#!/bin/bash

rancher_command=rancher
rancher_cli=./scripts/rancher-cli.py

function check_health() {
    local health_check_url=$1

    ISOK=0
    COUNT=0
    while [ $ISOK -eq 0 ]; do
        echo "Waiting on Application $health_check_url ..."

        COUNT=$[$COUNT + 1]
        if [ $COUNT -gt 90 ]; then
            echo "Error: Application healthcheck timeout: ${health_check_url}"
            exit 1;
        fi

        ISOK=`curl -i -N -s ${health_check_url} --max-time 5 | head -1 | grep "200 OK" | wc -l`
        sleep 10
    done

    echo "${health_check_url} started"
    return 0;
}

function update_label() {
    label_key=$1
    label_value=$2

    echo "Updating Label $label_key=$label_value on $service.$stack"
    $rancher_cli --action=update-labels --host=$service.$stack --data="{\"$label_key\":\"$label_value\"}"
}

function rename_stack() {
    rename=$1

    projectId=`$rancher_command --env $env inspect --format '{{ .id}}' --type project $env`
    stackId=`$rancher_command --env $env inspect --format '{{ .id}}' --type stack $stack`
    echo "Renaming stack $stack with id: $projectId in env $env with Id: $stackId"

    echo ""

    rename_status=$(curl -o /dev/null -s -w "%{http_code}\n" -u "$RANCHER_ACCESS_KEY:$RANCHER_SECRET_KEY" \
        -X PUT \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$rename\"}" \
        "$RANCHER_URL/projects/${projectId}/stacks/${stackId}/")

    echo "response: $rename_status"
    if [[ $rename_status != 200 ]]
    then
        "ERROR: Failed to renamed service"
        exit 1
    fi
}


function ensure_upgrade_confirmation() {
    echo "Confirming previous unconfirmed Stack Upgrade"
    $rancher_command \
        --environment $env --debug --wait --wait-state healthy --wait-timeout $rancher_wait_timeout \
        up \
        -s $stack -f $docker_compose_file --rancher-file $rancher_compose_file --confirm-upgrade -d
    echo "Stack Upgrade successfully reconfirmed"
}

function confirm_upgrade() {
    # This function will confirm the stack without triggering a upgrade if composer files are different
    echo  "Confirming upgrade of $stack in $env"
    $rancher_cli --action=confirm-upgrade --host=$service.$stack
}

function check_stack_health() {
    health_status=`$rancher_command --environment $env inspect --format '{{ .healthState}}' --type stack $stack | head -n1`
    service_state=`$rancher_command --environment $env inspect --format '{{ .state}}' --type service $stack/$service | head -n1`

    echo "Current health status of stack: $health_status"
    echo "Current state of service: $service_state"

    if [[ "$health_status" != "healthy" ]]; then
        echo  "Stack is not in a healthy state. Exiting."
        exit 1
    fi

    if [[ $service_state == "upgraded" ]]; then
        confirm_upgrade
    fi
}

function generate_deployment_files() {
    echo "Generating deployment files"
    mkdir -p temp
    envsubst < $docker_compose_file > temp/docker-compose.yml
    envsubst < $rancher_compose_file > temp/rancher-compose.yml
}

function upgrade_stack() {
    echo  "Upgrading $stack in $env"
    $rancher_command \
        --env $env \
        --debug \
        --wait --wait-timeout $rancher_wait_timeout \
        --wait-state healthy \
        up \
        --pull \
        --batch-size 1 \
        --stack $stack \
        --file temp/docker-compose.yml \
        --rancher-file temp/rancher-compose.yml \
        --force-upgrade \
        --confirm-upgrade -d
}
