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
# from its own cached emsdk copy. That tries to download node-v20.18.0 from
# Google Cloud Storage which returns 403. Fix: fetch Zig deps first, then
# pre-populate the node directory in the cached emsdk so it skips the download.
ENV ZIG_EMSDK_CACHE="/root/.cache/zig/p/N-V-__8AAJl1DwBezhYo_VE6f53mPVm00R-Fk28NPW7P14EQ"
RUN zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseSmall --fetch \
    && mkdir -p "${ZIG_EMSDK_CACHE}/node/20.18.0_64bit/bin" \
    && ln -s "$(which node)" "${ZIG_EMSDK_CACHE}/node/20.18.0_64bit/bin/node"

# Now the actual build — emsdk will see node as "already installed" and skip download
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
