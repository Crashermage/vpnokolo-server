# https://remna.st/docs/install/remnawave-panel
apt-get -y update && apt-get -y upgrade

# ставим Docker
sudo curl -fsSL https://get.docker.com | sh

# создаем директорию для панели и переходим
mkdir /opt/remnawave && cd /opt/remnawave 

# ставим настройки для докера
curl -o docker-compose.yml https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/docker-compose-prod.yml

# .env файл с параметрами для запуска контейнеров
curl -o .env https://raw.githubusercontent.com/remnawave/backend/refs/heads/main/.env.sample

# создание ключей безопасности
sed -i "s/^JWT_AUTH_SECRET=.*/JWT_AUTH_SECRET=$(openssl rand -hex 64)/" .env && sed -i "s/^JWT_API_TOKENS_SECRET=.*/JWT_API_TOKENS_SECRET=$(openssl rand -hex 64)/" .env

# создание паролей
sed -i "s/^METRICS_PASS=.*/METRICS_PASS=$(openssl rand -hex 64)/" .env && sed -i "s/^WEBHOOK_SECRET_HEADER=.*/WEBHOOK_SECRET_HEADER=$(openssl rand -hex 64)/" .env
 
# создаем уникальный пароль для Postgres БД
pw=$(openssl rand -hex 24) && sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$pw/" .env && sed -i "s|^\(DATABASE_URL=\"postgresql://postgres:\)[^\@]*\(@.*\)|\1$pw\2|" .env
 
# редактируем .env
vim .env
# ставим
FRONT_END_DOMAIN=remn.vpn-okolo.com
SUB_PUBLIC_DOMAIN=sub.vpn-okolo.com

# запускаем контейнеры
docker compose up -d && docker compose logs -f -t

# выпускаем SSL сертификат
# устанавливаем зависимости
sudo apt-get install cron socat 
curl https://get.acme.sh | sh -s email=crashermage@gmail.com && source ~/.bashrc
# создаем папку для сертификатов
mkdir -p /opt/remnawave/nginx && cd /opt/remnawave/nginx
ufw enable && ufw allow OpenSSH
acme.sh --set-default-ca --server letsencrypt
ufw allow 80/tcp
acme.sh --issue --standalone -d 'remn.vpn-okolo.com' --key-file /opt/remnawave/nginx/privkey.key --fullchain-file /opt/remnawave/nginx/fullchain.pem

#создаем конфиг nginx
cd /opt/remnawave/nginx && nano nginx.conf

#вставляем
upstream remnawave {
    server remnawave:3000;
}

server {
    server_name remn.vpn-okolo.com;

    listen 443 ssl reuseport;
    listen [::]:443 ssl reuseport;
    http2 on;

    location / {
        proxy_http_version 1.1;
        proxy_pass http://remnawave;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # SSL Configuration (Mozilla Intermediate Guidelines)
    ssl_protocols          TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets    off;
    ssl_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/privkey.key";
    ssl_trusted_certificate "/etc/nginx/ssl/fullchain.pem";

    ssl_stapling           on;
    ssl_stapling_verify    on;
    resolver               1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=60s;
    resolver_timeout       2s;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;

    ssl_reject_handshake on;
}

# прописываем настройки докера для nginx
cd /opt/remnawave/nginx && nano docker-compose.yml

services:
    remnawave-nginx:
        image: nginx:1.28
        container_name: remnawave-nginx
        hostname: remnawave-nginx
        volumes:
            - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
            - ./fullchain.pem:/etc/nginx/ssl/fullchain.pem:ro
            - ./privkey.key:/etc/nginx/ssl/privkey.key:ro
        restart: always
        ports:
            - '0.0.0.0:443:443'
        networks:
            - remnawave-network

networks:
    remnawave-network:
        name: remnawave-network
        driver: bridge
        external: true.
        
# запускаем контейнер
docker compose up -d && docker compose logs -f -t
 
# добавим страницу пользователя
cd /opt/remnawave && nano .env
# ставим
SUB_PUBLIC_DOMAIN=sub.vpn-okolo.com
# перезапускаем докер
cd /opt/remnawave && docker compose down remnawave && docker compose up -d && docker compose logs -f
# создаем отдельный docker compose
mkdir -p /opt/remnawave/subscription && cd /opt/remnawave/subscription && nano docker-compose.yml

# вставляем
services:
    remnawave-subscription-page:
        image: remnawave/subscription-page:latest
        container_name: remnawave-subscription-page
        hostname: remnawave-subscription-page
        restart: always
        env_file:
            - .env
        ports:
            - '127.0.0.1:3010:3010'
        networks:
            - remnawave-network

networks:
    remnawave-network:
        driver: bridge
        external: true
        
mkdir -p /opt/remnawave/subscription && cd /opt/remnawave/subscription && nano .env

# вставляем
APP_PORT=3010
REMNAWAVE_PANEL_URL=https://remn.vpn-okolo.com
META_TITLE="Subscription page"
META_DESCRIPTION="Subscription page description"

docker compose up -d && docker compose logs -f # запускаем контейнер
acme.sh --issue --standalone -d 'sub.vpn-okolo.com' --key-file /opt/remnawave/nginx/subdomain_privkey.key --fullchain-file /opt/remnawave/nginx/subdomain_fullchain.pem
cd /opt/remnawave/nginx && nano nginx.conf

# добавляем вверху 
upstream remnawave-subscription-page {
    server remnawave-subscription-page:3010;
}

# внизу добавляем это
server {
    server_name sub.vpn-okolo.com;

    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;

    location / {
        proxy_http_version 1.1;
        proxy_pass http://remnawave-subscription-page;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # SSL Configuration (Mozilla Intermediate Guidelines)
    ssl_protocols          TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;

    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets    off;
    ssl_certificate "/etc/nginx/ssl/subdomain_fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/subdomain_privkey.key";
    ssl_trusted_certificate "/etc/nginx/ssl/subdomain_fullchain.pem";

    ssl_stapling           on;
    ssl_stapling_verify    on;
    resolver               1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=60s;
    resolver_timeout       2s;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/x-javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/xhtml+xml
        application/xml
        font/eot
        font/otf
        font/ttf
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;
}

# прокидываем новые сертификаты
cd /opt/remnawave/nginx && nano docker-compose.yml

# добавляем эти строки в volumes
            - ./subdomain_fullchain.pem:/etc/nginx/ssl/subdomain_fullchain.pem:ro
            - ./subdomain_privkey.key:/etc/nginx/ssl/subdomain_privkey.key:ro
# перезапускаем контейнер nginx
docker compose down && docker compose up -d && docker compose logs -f
