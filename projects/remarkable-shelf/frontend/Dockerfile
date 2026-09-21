FROM node:20-alpine AS builder
WORKDIR /app
COPY reMarkableShelf/frontend/package.json reMarkableShelf/frontend/package-lock.json* ./
RUN npm install
COPY reMarkableShelf/frontend .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY formation-playbooks/projects/remarkable-shelf/frontend/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
