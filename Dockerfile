FROM nginx:alpine

VOLUME /var/www/html
COPY nginx.conf /etc/nginx/nginx.conf
RUN chgrp -R 0 /var/www/html && \
    chmod -R g=u /var/www/html && \
    chgrp -R 0 /var/cache/nginx && \
    chmod -R g=u /var/cache/nginx
