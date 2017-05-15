RANCHER_CHECK_TIMEOUT ?= 360

deploy: rancherUpgrade healthCheck

rancherUpgrade:
	/scripts/rancher_deploy.sh -e $(RANCHER_ENVIRONMENT) \
		-s $(RANCHER_STACK) \
		-c $(RANCHER_SERVICE) \
		-d $(DOCKER_COMPOSE) \
		-n $(RANCHER_COMPOSE) \
		-w $(RANCHER_CHECK_TIMEOUT)

healthCheck:
	timeout $(RANCHER_CHECK_TIMEOUT) /scripts/rancher_ping_url.sh ${HEALTHCHEKCURL}

healthCheckGreen:
	timeout $(RANCHER_CHECK_TIMEOUT) /scripts/rancher_ping_url.sh ${HEALTHCHEKCURL_GREEN}	