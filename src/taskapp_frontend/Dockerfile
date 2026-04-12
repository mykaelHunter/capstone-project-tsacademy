# STAGE 1
FROM node:24-alpine AS builder

# Set Working Directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install Deps
RUN npm ci --frozen-lockfile

# Copy source code
COPY . .

ENV VITE_API_URL=https://api.<your-domain>/api

# Build App
RUN npm run build


# STAGE 2
FROM nginx:alpine

# Configure nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port 80
EXPOSE 80
