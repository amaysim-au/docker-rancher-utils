#!/bin/bash -e

source /scripts/libs/_rancher.sh

usage="$(basename "$0") [-h] [-a ACTION] [-e ENVIRONMENT] [-s STACK] [-c SERVICE] [-r RANCHER_COMMAND] [-d DOCKER_COMPOSE_FILE] [-n RANCHER_COMPOSE_FILE] [-w WAIT_TIME_SECS] -- script to cutover rancher blue-green deployments.
Make sure that you have rancher environment options set and rancher cli installed before running the script.

where:
-h  show this help text
-a  set the action to perform: deploy, cutover or rollback (default: deploy)
-e  set the rancher environment (default: Dev)
-s  set the rancher stack (default: QA)
-c  set the rancher service (default: poseidon-app)
-r  set the rancher command (default: ./rancher)
-d  set the docker-compose file (default: deployment/docker-compose.yml)
-n  set the rancher-compose file (default: deployment/rancher-compose.yml)
-w  set the wait time in seconds (default: 120)"

action=deploy
env=Dev
stack=test-stack
service=test-service
rancher_wait_timeout=360

docker_compose_file=deployment/docker-compose.yml
rancher_compose_file=deployment/rancher-compose.yml

lbconfig_file=deployment/lbconfig.json
lbconfig_green_file=deployment/lbconfig-green.json


while getopts ':a:e:s:c:r:w:d:n:h' option; do
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
        w)  rancher_wait_timeout=$OPTARG
            ;;
        a)  action=$OPTARG
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

stack_exists=`$rancher_command --env $env inspect --type stack $stack | head -n1`
echo "Stack exists: $stack_exists"

if [[ $stack_exists == "" ]]; then
    echo "empty result - not authorized to call Rancher API"
    exit 1
fi

is_bluegreen=${HEALTHCHECKURL_GREEN:-"false"}
echo "Is blue green?: $is_bluegreen"

# RANCHER_PROJECT_ID=`$rancher_command --env $env env -q`
# echo "rancher project id: $RANCHER_PROJECT_ID"
#
# RANCHER_LB_ID=`$rancher_cli --action=get-svc-id --host=haproxy-https.Infrastructure`
# echo "rancher loadbalancer id: $RANCHER_LB_ID"
#
# RANCHER_SERVICE_ID=`$rancher_cli --action=get-svc-id --host=$service.$stack`
# echo "rancher service id: $RANCHER_SERVICE_ID"

generate_deployment_files

if [[ $stack_exists == *"Not found"* ]]; then
    echo "stack not found"
    exit 1
fi

if [[ $action == "deploy" ]]; then

    confirm_upgrade

    check_stack_health

    if [[ ${is_bluegreen} != "false" ]]; then
        # Is Blue Green deployment

        # Rename $stack to $stack-blue (live)
        rename_stack "$stack-blue"

        # This will create the $stack
        upgrade_stack

        # Put the new stack in the green load balancer
        update_label "lb" "$service-green"

        check_stack_health

        check_health $HEALTHCHECKURL_GREEN
    else

        upgrade_stack

        check_stack_health

        check_health $HEALTHCHECKURL
    fi

elif [[ $action == "cutover" ]]; then

    # Updating label on $stack so it start serving requests
    update_label "lb" "$service"

    # Waiting 30 seconds for the service to stabilise
    echo "Waiting 30 seconds for service"
    sleep 30

    # Saving stack name (now live)
    stack_green=$stack

    # Disabling old stack (blue)
    stack="$stack-blue"
    update_label "lb" "$service-green"

    # Rename blue to delete
    rename_stack "$stack_green-to-delete"

fi

exit 0
