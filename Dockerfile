# ============================================================
# Stage 1: Build Zig + Emscripten → WASM
# ============================================================
FROM debian:bookworm-slim AS builder

ARG ZIG_VERSION=0.15.2
ARG EMSDK_VERSION=4.0.9

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    git \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Zig (note: 0.15+ uses arch-os naming convention)
RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /opt \
    && ln -s /opt/zig-x86_64-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

# Install Emscripten SDK
RUN git clone https://github.com/emscripten-core/emsdk.git /opt/emsdk \
    && cd /opt/emsdk \
    && ./emsdk install ${EMSDK_VERSION} \
    && ./emsdk activate ${EMSDK_VERSION}

ENV PATH="/opt/emsdk:/opt/emsdk/upstream/emscripten:${PATH}"
ENV EMSDK="/opt/emsdk"

# Copy project source
WORKDIR /app
COPY . .

# Fetch Zig dependencies and build for Emscripten/WASM
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
