# This Dockerfile contains scripts to deploy to rancher
FROM alpine:3.5
ENV RANCHER_CLI_URL https://github.com/rancher/cli/releases/download/v0.6.4/rancher-linux-amd64-v0.6.4.tar.xz
RUN apk --no-cache update && \
    apk --no-cache add ca-certificates sudo bash wget unzip make coreutils curl && \
    update-ca-certificates && \
    rm -rf /var/cache/apk/*
RUN \
    apk add --update gettext && \
    apk add --virtual build_deps libintl &&  \
    cp /usr/bin/envsubst /usr/local/bin/envsubst && \
    apk del build_deps

RUN apk add --update \
    python \
    py-pip \
    && pip install requests pyyaml \
    && rm -rf /var/cache/apk/*

RUN wget -qO- $RANCHER_CLI_URL | tar xvJ && \
	mv ./rancher-v0.6.4/rancher /usr/local/bin/rancher
ADD scripts /scripts
RUN chmod a+x /scripts/*.sh && chmod a+x /scripts/libs/*.sh
CMD ["rancher", "--version"]
