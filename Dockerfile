# Build the binary
FROM golang:1.18.3-alpine3.16 as base

ENV GO111MODULE=auto
ENV CGO_ENABLED=0

RUN echo "https://mirror.csclub.uwaterloo.ca/alpine/v3.16/main" >/etc/apk/repositories && \
    echo "https://mirror.csclub.uwaterloo.ca/alpine/v3.16/community" >>/etc/apk/repositories && \
    apk update && \
    apk add --no-cache bash curl coreutils file git && \
    mkdir /src

COPY . /src
WORKDIR /src

ARG PKG=github.com/distribution/distribution/v3
RUN VERSION=$(git describe --match 'v[0-9]*' --dirty='.m' --always --tags) REVISION=$(git rev-parse HEAD)$(if ! git diff --no-ext-diff --quiet --exit-code; then echo .m; fi); \
  echo "-X ${PKG}/version.Version=${VERSION#v} -X ${PKG}/version.Revision=${REVISION} -X ${PKG}/version.Package=${PKG}" | tee /tmp/.ldflags; \
  echo -n "${VERSION}" | tee /tmp/.version;

ARG TARGETPLATFORM
ARG LDFLAGS="-s -w"
ARG BUILDTAGS="include_oss include_gcs"
RUN go build -trimpath -ldflags "$(cat /tmp/.ldflags) ${LDFLAGS}" -o /usr/bin/registry ./cmd/registry

# Copy binary from the build step.
FROM scratch AS binary
COPY --from=base /usr/bin/registry /

FROM alpine:3.16
RUN apk add --no-cache ca-certificates
COPY cmd/registry/config-dev.yml /etc/docker/registry/config.yml
COPY --from=binary /registry /bin/registry
VOLUME ["/var/lib/registry"]
EXPOSE 5000
ENTRYPOINT ["registry"]
CMD ["serve", "/etc/docker/registry/config.yml"]
