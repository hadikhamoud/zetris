# ============================================================
# Stage 1: Build Zig + Emscripten → WASM
# ============================================================
# Use the official Emscripten SDK image — has emcc, node, python all pre-installed
FROM emscripten/emsdk:4.0.9 AS builder

ARG ZIG_VERSION=0.15.2

# Install only what's needed for Zig
RUN apt-get update && apt-get install -y --no-install-recommends \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig (note: 0.15+ uses arch-os naming convention)
RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
    && ln -s /opt/zig-x86_64-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

# Copy project source
WORKDIR /app
COPY . .

# Zig's raylib dependency uses zemscripten which runs "emsdk install 4.0.3"
# from this cached emsdk copy. Pre-install it here with retries so the actual
# build step does not have to fetch toolchain artifacts anymore.
ENV ZIG_EMSDK_CACHE="/root/.cache/zig/p/N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ"
RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall --fetch \
    && chmod +x "${ZIG_EMSDK_CACHE}/emsdk" \
    && i=0; until [ "$i" -ge 5 ]; do "${ZIG_EMSDK_CACHE}/emsdk" install 4.0.3 && break; i=$((i + 1)); echo "emsdk install retry $i/5"; sleep 5; done \
    && [ "$i" -lt 5 ] \
    && "${ZIG_EMSDK_CACHE}/emsdk" activate 4.0.3

# Now the actual build — emsdk sees node + upstream as "already installed"
RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall

# ============================================================
# Stage 2: Serve with Nginx
# ============================================================
FROM nginx:alpine AS runtime

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy our nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built web files from builder stage
COPY --from=builder /app/zig-out/web/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO /dev/null http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
