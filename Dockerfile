FROM emscripten/emsdk:4.0.9 AS builder

ARG ZIG_VERSION=0.15.2

RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
    && ln -s /opt/zig-x86_64-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

WORKDIR /app
COPY . .

RUN zig build --fetch

RUN python3 scripts/patch_zemscripten.py

RUN set -eux; \
    for d in /root/.cache/zig/p/N-V-*; do \
        if [ -f "$d/emsdk" ]; then \
            rm -rf "$d"; \
            ln -s /emsdk "$d"; \
        fi; \
    done

RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall

FROM nginx:alpine AS runtime

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/zig-out/web/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -qO /dev/null http://127.0.0.1:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
