FROM emscripten/emsdk:4.0.9 AS builder

ARG ZIG_VERSION=0.15.2
ARG EMSDK_VERSION=4.0.9

RUN apt-get update && apt-get install -y --no-install-recommends \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
    && ln -s /opt/zig-x86_64-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

WORKDIR /app
COPY . .

RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall --fetch \
    && for f in /root/.cache/zig/p/zemscripten-*/build.zig; do sed -i "s/pub const emsdk_ver_tiny = \"3\";/pub const emsdk_ver_tiny = \"9\";/" "$f"; done \
    && set -- /root/.cache/zig/p/N-V-*/emsdk \
    && chmod +x "$1" \
    && i=0; until [ "$i" -ge 5 ]; do "$1" install "${EMSDK_VERSION}" && break; i=$((i + 1)); echo "emsdk install retry $i/5"; sleep 5; done \
    && [ "$i" -lt 5 ] \
    && "$1" activate "${EMSDK_VERSION}"

RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall

FROM nginx:alpine AS runtime

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/zig-out/web/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -qO /dev/null http://127.0.0.1:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
