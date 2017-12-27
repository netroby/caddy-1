FROM centos

RUN yum update -y
RUN yum install -y curl
RUN curl https://getcaddy.com | bash -s personal tls.dns.cloudflare
RUN mv /usr/local/bin/caddy /usr/bin/caddy

# set default caddypath
ENV CADDYPATH=/etc/.caddy
VOLUME /etc/.caddy


ENTRYPOINT ["/bin/caddy"]
CMD ["--conf", "/etc/Caddyfile", "--log", "stdout"]
