FROM nginx

MAINTAINER @msfukui
LABEL org.opencontainers.image.source https://github.com/msfukui/msfukui.page

RUN rm /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY public /usr/share/nginx/html
COPY docker/nginx/conf /etc/nginx
RUN find /usr/share/nginx/html -type d -exec chmod o+rx {} +
RUN find /usr/share/nginx/html -type f -exec chmod o+r  {} +
