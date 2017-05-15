#!/bin/bash

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

    ISOK=`curl -i -s ${health_check_url} --max-time 5 | head -1 | grep "200 OK" | wc -l`
    sleep 10
  done

  echo "${health_check_url} started"
  return 0;
}
