# Multi-stage build for Vue.js frontend application
# Stage 1: Build the Vue.js application
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Add package files for dependency installation
COPY package*.json ./

# Install dependencies with npm ci for faster, reliable, reproducible builds
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Build the application for production
RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:1.25-alpine AS production

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create nginx user and group
RUN addgroup -g 101 -S nginx && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

# Copy built application from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy custom entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create required directories and set permissions
RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /etc/nginx

# Switch to non-root user
USER nginx

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Use dumb-init as entrypoint for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]