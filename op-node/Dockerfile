FROM golang:1.21 AS build-op-node

WORKDIR /app

ENV REPO=https://github.com/ethereum-optimism/optimism.git
ENV VERSION=v1.9.3
# for verification:
ENV COMMIT=e81c50de0a51954c64444b849be4768c8116cffb

RUN git clone $REPO --branch op-node/$VERSION --single-branch . && \
    git switch -c branch-$VERSION && \
    bash -c '[ "$(git rev-parse HEAD)" = "$COMMIT" ]'

RUN cd op-node && make VERSION=$VERSION op-node

FROM golang:1.21

RUN apt-get update && \
    apt-get install netcat-openbsd && \
    apt-get install -y jq curl supervisor && \
    rm -rf /var/lib/apt/lists
RUN mkdir -p /var/log/supervisor

WORKDIR /app

COPY --from=build-op-node /app/op-node/bin/op-node ./
COPY op-node/config /config
COPY op-node/entrypoint.sh entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENTRYPOINT [ "./entrypoint.sh" ]
