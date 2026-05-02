# ===== STAGE 1: React app ko build karo =====
FROM node:20-alpine AS build

WORKDIR /app

# Pehle sirf package files copy karo (cache ke liye)
COPY package*.json ./

# npm ci = clean install, tezz aur reliable
RUN npm ci

# Baki saara code copy karo
COPY . .

# Build time pe API ka URL chahiye (Vite isko bundle me daal deta hai)
# Default "/api" matches the Caddy reverse-proxy route (Caddy strips /api → backend:8000)
ARG VITE_API_URL=/api
ENV VITE_API_URL=$VITE_API_URL

# React app ko production build karo (output dist/ folder me)
RUN npm run build


# ===== STAGE 2: nginx ke through serve karo =====
FROM nginx:alpine

# Build folder ko nginx ke web folder me copy karo
COPY --from=build /app/dist /usr/share/nginx/html

# Apna custom nginx config copy karo
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
