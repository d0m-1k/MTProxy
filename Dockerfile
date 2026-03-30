# ---
# BUILD BINARY
# ---
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential git make gcc \
    libssl-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Исправление assert уже присутствует в исходном коде форка
RUN make clean && make

# ---
# RUN
# ---
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/objs/bin/mtproto-proxy /usr/local/bin/mtproto-proxy

RUN mkdir -p /etc/mtproxy /var/run/mtproxy

EXPOSE 1443 8888

ENTRYPOINT ["/usr/local/bin/mtproto-proxy"]
CMD ["-u", "nobody", "-p", "8888", "-H", "1443", "-S", "/secret", "--aes-pwd", "/proxy-secret", "/proxy-multi.conf", "-M", "1"]
