apt-get -y update && apt-get -y upgrade

# включаем firewall, но оставляем порт 22 для SSH
ufw enable && ufw allow OpenSSH
# открываем нужные порты
ufw allow 443,2222/tcp
 
# настраиваем правило для запрета icmp запросов
vim /etc/ufw/before.rules 
 
# ищем ok icmp code for INPUT  и ok icmp code for FORWARD
меняем все ACCEPT на DROP
 
# в блок for INPUT добавляем:
-A ufw-before-input -p icmp --icmp-type source-quench -j DROP

# перезапускаем firefall
ufw disable && ufw enable 

# устанавливаем docker
sudo curl -fsSL https://get.docker.com | sh
# создаем раб.директорию
mkdir /opt/remnanode && cd /opt/remnanode
# редактируем файл конфига
vim .env 

# вставляем 
APP_PORT=2222
SSL_CERT=# переходим в панель и добавляя новую ноду копируем сертификат

# создаем docker compose
vim docker-compose.yml

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


 
 
