TIMOUT ?= 100

deploy:
	/scripts/rancher_deploy.sh -e $(RANCHER_ENVIRONMENT) \
		-s $(RANCHER_STACK) \
		-c $(RANCHER_SERVICE) \
		-d $(DOCKER_COMPOSE) \
		-n $(RANCHER_COMPOSE) \
		-w 300
	timeout $(TIMOUT) /scripts/rancher_check_if_app_is_ip.sh