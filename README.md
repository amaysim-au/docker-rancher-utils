# Docker Rancher Utils

A lightweight image containing rancher cli and scripts to ease rancher management.

## Deploy Script

The deploy script deploys a new container to Rancher. It also deploys a sumologic container.

For an example how to use it, see the Makefile target `deploy` (along with `.env.example` and `docker-compose.yml`).

## Usage

Run from inside the shell:

    >make shell
    >make -f scripts/Makefile deploy

Run using container

    docker run amaysim/rancher-utils make -f scripts/Makefile deploy