RANCHER_CHECK_TIMEOUT ?= 360

deploy: rancherUpgrade

rancherUpgrade:
	/scripts/rancher_deploy.sh -a deploy \
		-e $(RANCHER_ENVIRONMENT) \
		-s $(RANCHER_STACK) \
		-c $(RANCHER_SERVICE) \
		-d $(DOCKER_COMPOSE) \
		-n $(RANCHER_COMPOSE) \
		-w $(RANCHER_CHECK_TIMEOUT)

cutover:
	/scripts/rancher_deploy.sh -a cutover \
		-e $(RANCHER_ENVIRONMENT) \
		-s $(RANCHER_STACK) \
		-c $(RANCHER_SERVICE) \
		-d $(DOCKER_COMPOSE) \
		-n $(RANCHER_COMPOSE) \
		-w $(RANCHER_CHECK_TIMEOUT)

healthCheck:
	timeout $(RANCHER_CHECK_TIMEOUT) /scripts/rancher_ping_url.sh $(HEALTHCHECKURL)

healthCheckGreen:
	timeout $(RANCHER_CHECK_TIMEOUT) /scripts/rancher_ping_url.sh $(HEALTHCHECKURL_GREEN)
