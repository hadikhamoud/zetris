FROM emscripten/emsdk:4.0.9 AS builder

ARG ZIG_VERSION=0.15.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
    && ln -s /opt/zig-x86_64-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

WORKDIR /app
COPY . .

ENV ZIG_EMSDK_CACHE="/root/.cache/zig/p/N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ"
RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall --fetch \
    && chmod +x "${ZIG_EMSDK_CACHE}/emsdk" \
    && i=0; until [ "$i" -ge 5 ]; do "${ZIG_EMSDK_CACHE}/emsdk" install 4.0.3 && break; i=$((i + 1)); echo "emsdk install retry $i/5"; sleep 5; done \
    && [ "$i" -lt 5 ] \
    && "${ZIG_EMSDK_CACHE}/emsdk" activate 4.0.3

RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall

FROM nginx:alpine AS runtime

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/zig-out/web/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -qO /dev/null http://127.0.0.1:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
