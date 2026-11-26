# The GatherInsight landing page: static HTML served by nginx on Cloud Run (port 8080).
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html id.html platform.html platform-id.html favicon.svg /usr/share/nginx/html/
COPY img/ /usr/share/nginx/html/img/
