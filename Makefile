RANCHER_CLI_VERSION = 0.2.0
IMAGE_NAME ?= amaysim/rancher-cli:$(RANCHER_CLI_VERSION)
TAG = v$(RANCHER_CLI_VERSION)

build:
	docker build -t $(IMAGE_NAME) .

shell:
	docker run --rm -it -v $(PWD):/opt/app $(IMAGE_NAME) bash

gitTag:
	-git tag -d $(TAG)
	-git push origin :refs/tags/$(TAG)
	git tag $(TAG)
	git push origin $(TAG)