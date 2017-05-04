RANCHER_CHECK_TIMEOUT ?= 360

deploy:
	/scripts/rancher_deploy.sh -e $(RANCHER_ENVIRONMENT) \
		-s $(RANCHER_STACK) \
		-c $(RANCHER_SERVICE) \
		-d $(DOCKER_COMPOSE) \
		-n $(RANCHER_COMPOSE) \
		-w $(RANCHER_CHECK_TIMEOUT)
	timeout $(RANCHER_CHECK_TIMEOUT) /scripts/rancher_check_if_app_is_up.sh