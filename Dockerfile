FROM nginx

LABEL maintainer="msfukui@gmail.com"
LABEL org.opencontainers.image.authors="msfukui@gmail.com"
LABEL org.opencontainers.image.url="https://github.com/msfukui/msfukui.page"
LABEL org.opencontainers.image.source="https://github.com/msfukui/msfukui.page/blob/master/Dockerfile"
LABEL org.opencontainers.image.documentation="msfukui's website for pitanetes"
LABEL org.opencontainers.image.version="0.0.3"

RUN rm /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/nginx/conf /etc/nginx
COPY public /usr/share/nginx/html
RUN find /usr/share/nginx/html -type d -exec chmod o+rx {} +
RUN find /usr/share/nginx/html -type f -exec chmod o+r  {} +
