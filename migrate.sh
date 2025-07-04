#!/bin/bash

touch /home/awgmode.txt
echo "server" > /home/awgmode.txt
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get -y update
apt-get -y upgrade
apt-get install -y git software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r) zstd sudo
add-apt-repository -y ppa:amnezia/ppa
apt-get -y update
apt-get -y upgrade
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/00-amnezia.conf
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
echo net.ipv4.conf.all.src_valid_mark=1 >> /etc/sysctl.conf
sysctl -p
mkdir /app
git clone https://github.com/amnezia-vpn/amneziawg-tools.git /app
apt-get install -y make g++ gcc
cd /app/src && make && make install
ln -s /app/amneziawg-tools/src/wg /usr/bin/
ln -s /app/amneziawg-tools/src/wg-quick/wg-quick /usr/bin/
apt-get install -y \
    dpkg \
    dumb-init \
    iptables \
    iproute2
update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save
rm -f /usr/bin/wg-quick
ln -s /usr/bin/awg-quick /usr/bin/wg-quick
apt-get install amneziawg -y
mkdir -p /etc/amnezia/amneziawg

docker cp amnezia-awg:/opt/amnezia/awg/wireguard_server_private_key.key /etc/amnezia/amneziawg
docker cp amnezia-awg:/opt/amnezia/awg/wireguard_server_public_key.key /etc/amnezia/amneziawg
docker cp amnezia-awg:/opt/amnezia/awg/wireguard_psk.key /etc/amnezia/amneziawg
docker cp amnezia-awg:/opt/amnezia/awg/wg0.conf /etc/amnezia/amneziawg

docker stop amnezia-awg

CONFIG_FILE="/etc/amnezia/amneziawg/wg0.conf"
SERVICE_FILE="/etc/systemd/system/vpnokolo.service"

MASK=$(grep -oP 'Address\s*=\s*\K[^\s]+' $CONFIG_FILE)
PORT=$(grep -oP 'ListenPort\s*=\s*\K\d+' $CONFIG_FILE)

IPTABLES_RULES="iptables -t nat -A POSTROUTING -s $MASK -o eth0 -j MASQUERADE; iptables -A INPUT -p udp -m udp --dport $PORT -j ACCEPT; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT;"
awg-quick up /etc/amnezia/amneziawg/wg0.conf

echo "[Unit]
Description=WireGuard via wg-quick
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/wg-quick up /etc/amnezia/amneziawg/wg0.conf
ExecStartPost=/bin/bash -c '$IPTABLES_RULES'
ExecStop=/usr/bin/wg-quick down /etc/amnezia/amneziawg/wg0.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" > $SERVICE_FILE

systemctl daemon-reload

systemctl enable vpnokolo.service
systemctl start vpnokolo.service
iptables-save -t nat
