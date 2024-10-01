FROM golang:1.21 AS build-op-geth

WORKDIR /app

ENV REPO=https://github.com/ethereum-optimism/op-geth.git
ENV VERSION=v1.101315.3
# for verification:
ENV COMMIT=8af19cf20261c0b62f98cc27da3a268f542822ee

RUN git clone $REPO --branch $VERSION --single-branch . && \
    git switch -c branch-$VERSION && \
    bash -c '[ "$(git rev-parse HEAD)" = "$COMMIT" ]'

RUN go run build/ci.go install -static ./cmd/geth

FROM golang:1.21 AS run-op-geth

RUN apt-get update && \
    apt-get install netcat-openbsd && \
    apt-get install -y jq curl supervisor && \
    rm -rf /var/lib/apt/lists
RUN mkdir -p /var/log/supervisor

WORKDIR /app

COPY --from=build-op-geth /app/build/bin/geth ./
COPY op-geth/config /config
COPY op-geth/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh


ENTRYPOINT [ "./entrypoint.sh" ]
