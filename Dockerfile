#
# Build stage by @abiosoft https://github.com/abiosoft/caddy-docker
#
FROM golang:1.9-alpine as build

ARG version="0.10.10"
ARG plugins="tls.dns.cloudflare"

RUN apk add --no-cache git

# caddy
RUN git clone https://github.com/mholt/caddy -b "v${version}" /go/src/github.com/mholt/caddy \
    && cd /go/src/github.com/mholt/caddy \
    && git checkout -b "v${version}"

# plugin helper
RUN go get -v github.com/abiosoft/caddyplug/caddyplug

# plugins
RUN for plugin in $(echo $plugins | tr "," " "); do \
    go get -v $(caddyplug package $plugin); \
    printf "package caddyhttp\nimport _ \"$(caddyplug package $plugin)\"" > \
        /go/src/github.com/mholt/caddy/caddyhttp/$plugin.go ; \
    done

# builder dependency
RUN git clone https://github.com/caddyserver/builds /go/src/github.com/caddyserver/builds

# build
RUN cd /go/src/github.com/mholt/caddy/caddy \
    && git checkout -f \
    && go run build.go \
    && mv caddy /go/bin


#
# Compress Caddy with upx
#
FROM debian:stable as compress

# curl, tar
RUN apt-get update && apt install -y --no-install-recommends \
    tar \
    xz-utils \
    curl \
    ca-certificates

# get official upx binary
RUN curl --silent --show-error --fail --location -o - \
    "https://github.com/upx/upx/releases/download/v3.94/upx-3.94-amd64_linux.tar.xz" \
    | tar --no-same-owner -C /usr/bin/ -xJ \
    --strip-components 1 upx-3.94-amd64_linux/upx

# copy and compress
COPY --from=build /go/bin/caddy /usr/bin/caddy
RUN /usr/bin/upx --ultra-brute /usr/bin/caddy

# test
RUN /usr/bin/caddy -version


#
# Final image
#
FROM scratch

# labels
LABEL org.label-schema.vcs-url="https://github.com/productionwentdown/caddy"
LABEL org.label-schema.version=${version}
LABEL org.label-schema.schema-version="1.0"

# copy caddy binary and ca certs
COPY --from=compress /usr/bin/caddy /bin/caddy
COPY --from=compress /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# copy default caddyfile
COPY Caddyfile /etc/Caddyfile

# set default caddypath
ENV CADDYPATH=/etc/.caddy
VOLUME /etc/.caddy

# serve from /srv
WORKDIR /srv
COPY index.html /srv/index.html

ENTRYPOINT ["/bin/caddy"]
CMD ["--conf", "/etc/Caddyfile", "--log", "stdout"]
