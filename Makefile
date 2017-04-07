VERSION = 1.0.0
IMAGE_NAME ?= amaysim/rancher-utils:$(VERSION)
TAG = v$(VERSION)

build:
	docker build -t $(IMAGE_NAME) .

shell:
	docker-compose down
	docker-compose run --rm shell

gitTag:
	-git tag -d $(TAG)
	-git push origin :refs/tags/$(TAG)
	git tag $(TAG)
	git push origin $(TAG)

# Example of how to deploy using docker compose
deploy:
	docker-compose down
	docker-compose run --rm deploy
