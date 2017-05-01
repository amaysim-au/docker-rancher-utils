#!/bin/bash -e

usage="$(basename "$0") [-h] [-e ENVIRONMENT] [-s STACK] [-c SERVICE] [-r RANCHER_COMMAND] [-d DOCKER_COMPOSE_FILE] [-n RANCHER_COMPOSE_FILE] [-w WAIT_TIME_SECS] -- script to upgrade and deploy containers in the given environment.
Make sure that you have rancher environment options set and rancher cli installed before running the script.

where:
-h  show this help text
-e  set the rancher environment (default: Dev)
-s  set the rancher stack (default: QA)
-c  set the rancher service (default: poseidon-app)
-r  set the rancher command (default: ./rancher)
-d  set the docker-compose file (default: deployment/docker-compose.yml)
-n  set the rancher-compose file (default: deployment/rancher-compose.yml)
-w  set the wait time in seconds (default: 120)"

env=Dev
stack=test-stack
service=test-service
rancher_command=rancher
docker_compose_file=deployment/docker-compose.yml
rancher_compose_file=deployment/rancher-compose.yml
WAIT_TIMEOUT=120
NUMBER_OF_TIMES_TO_LOOP=$(( $WAIT_TIMEOUT/10 ))

while getopts ':e:s:c:r:w:d:n:h' option; do
    case "$option" in
        h)  echo "$usage"
            exit
            ;;
        e)  env=$OPTARG
            ;;
        s)  stack=$OPTARG
            ;;
        c)  service=$OPTARG
            ;;
        r)  rancher_command=$OPTARG
            ;;
        d)  docker_compose_file=$OPTARG
            ;;
        n)  rancher_compose_file=$OPTARG
            ;;
        w)  WAIT_TIMEOUT=$OPTARG
            NUMBER_OF_TIMES_TO_LOOP=$(( $WAIT_TIMEOUT/10 ))
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

function rename_stack() {
    id=`$rancher_command --env $env inspect --format '{{ .id}}' --type stack $stack`
    echo "renaming $stack with id: $id"
    # curl -u "${RANCHER_ACCESS_KEY}:${RANCHER_SECRET_KEY}" \
    #     -X PUT \
    #     -H 'Content-Type: application/json' \
    #     -d '{
    #         "name": "$blue"
    #     }' 'http://${RANCHER_URL}/v2-beta/projects/${PROJECT_ID}/${stacks}/${ID}'
}

function upgrade_stack(){
    echo  "Upgrading $stack in $env"
    $rancher_command \
        --env $env \
        --debug \
        --wait --wait-timeout $WAIT_TIMEOUT \
        --wait-state "upgraded" \
        up \
        --batch-size 1 \
        --stack $stack \
        --file $docker_compose_file \
        --rancher-file $rancher_compose_file \
        --upgrade -p -d

    state_after_upgrade=`$rancher_command --env $env inspect --format '{{ .state}}' --type stack $stack | head -n1`
    echo  "The state of service after upgrade is $state_after_upgrade"
    case $state_after_upgrade in
        "active")  exit 0
                   ;;
        "upgraded") finish_upgrade
                   ;;
        *)  echo "Service isnt responding. Exiting."
            exit 1
            ;;
    esac
}

function finish_upgrade(){
    health_status=`$rancher_command --environment $env inspect --format '{{ .healthState}}' --type $stack/$service | head -n1`
    if [[ $health_status == "healthy" ]]
        then
            echo "Upgraded service successfully. Confirming Upgrade."
            $rancher_command --environment $env --debug --wait --wait-state active --wait-timeout $WAIT_TIMEOUT up -s $stack -f $docker_compose_file --rancher-file $rancher_compose_file --confirm-upgrade -d
            echo "Upgraded service successfully and confirmed."
            wait_for_service_to_have_status "healthy" ".healthState"
            exit 0
        else
            roll_back
    fi
}

function roll_back(){
    echo "Upgrade failed. Initiating rollback to the previous deployed version"
    $rancher_command --environment $env --debug --wait --wait-state active --wait-timeout $WAIT_TIMEOUT up --batch-size 1 -s $stack -f $docker_compose_file --rancher-file $rancher_compose_file --rollback -d
    wait_for_service_to_have_status "healthy" ".healthState"
    echo "Upgrade failed. Rolled back to the previous deployed version"
    exit 1
}

function check_stack_health() {
    health_status=`$rancher_command --environment $env inspect --format '{{ .healthState}}' --type stack $stack | head -n1`
    echo  "The current health status of service is $health_status"
    if [[ "$health_status" != "healthy" ]]
        then
        echo  "The Service is not in a healthy state. Exiting."
        exit 1
    fi
}

function confirm_upgrade_if_previous_upgrade_pending() {
    service_status=`$rancher_command --environment $env inspect --format '{{ .state}}' --type service $stack/$service | head -n1`
    echo  "The status of previous service upgrade is $service_status"
    if [[ "$service_status" == "upgraded" ]]
    then
        echo "Previous Upgrade not completed. Confirming the previous Upgrade before continuing."
        $rancher_command --environment $env --debug --wait --wait-state active --wait-timeout $WAIT_TIMEOUT up -s $stack -f $docker_compose_file --rancher-file $rancher_compose_file --confirm-upgrade -d
        wait_for_service_to_have_status "healthy" ".healthState"
    fi
}

function wait_for_service_to_have_status() {
    status_type=$1
    status_tag=$2
    status=`$rancher_command --environment $env inspect --format '{{ '"$status_tag"' }}' --type service $stack/$service | head -n1`
    echo "Waiting for service to be $status_type. Current status: $status"
    COUNT=0
    while [ $status != $status_type ]; do
        if [ $COUNT -gt $NUMBER_OF_TIMES_TO_LOOP ]; then
            echo "Error: Give up waiting for service status to be $status_type. Please investigate. Exiting."
            exit 1;
        fi
        COUNT=$[$COUNT + 1]
        echo "Waiting for service to be $status_type. Current status: $status"
        sleep 10
        status=`$rancher_command --environment $env inspect --format '{{ '"$status_tag"' }}' $stack/$service | head -n1`
    done
    echo "Service is now $status."
}

is_stack_exists=`$rancher_command --env $env inspect --type stack $stack | head -n1`
echo "stack exists: $is_stack_exists\n"
if [[ $is_stack_exists != *"Not found"* ]]
then
    check_stack_health
    confirm_upgrade_if_previous_upgrade_pending
    rename_stack
fi
upgrade_stack

