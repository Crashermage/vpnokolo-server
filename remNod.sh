apt-get -y update && apt-get -y upgrade

 ufw enable && ufw allow OpenSSH # включаем firewall, но оставляем порт 22 для SSH
 vim /etc/ufw/before.rules # настраиваем правило для запрета icmp запросов
 
 # ищем ok icmp code for INPUT  и ok icmp code for FORWARD
 меняем все ACCEPT на DROP
 
 # в блок for INPUT добавляем:
 -A ufw-before-input -p icmp --icmp-type source-quench -j DROP
 
 ufw disable && ufw enable # перезапускаем firefall
 
 sudo curl -fsSL https://get.docker.com | sh # устанавливаем docker
 mkdir /opt/remnanode && cd /opt/remnanode # создаем раб.директорию
 vim .env # редактируем файл конфига

# вставляем 
APP_PORT=2222
SSL_CERT=# переходим в панель и добавляя новую ноду копируем сертификат

# создаем docker compose
nano docker-compose.yml

# вставляем содержимое
services:
    remnanode:
        container_name: remnanode
        hostname: remnanode
        image: remnawave/node:latest
        restart: always
        network_mode: host
        env_file:
            - .env
 
 docker compose up -d && docker compose logs -f -t # запускаем нашу ноду

 ufw allow 1234/tcp
 ufw allow 443/tcp
 
 
