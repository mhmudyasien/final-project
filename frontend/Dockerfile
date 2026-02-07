# =========================
# Build stage
# =========================
FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

ENV GENERATE_SOURCEMAP=false

RUN npm run build && \
    rm -rf node_modules && \
    find build -name "*.map" -type f -delete

# =========================
# Production stage
# =========================
FROM alpine:latest

# Install nginx and create required directories
RUN apk add --no-cache nginx && \
    mkdir -p /run/nginx && \
    rm -rf /etc/nginx/conf.d/default.conf /usr/share/nginx/html/*

# Copy build artifacts and custom nginx configuration
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/http.d/default.conf

EXPOSE 80

# Run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
