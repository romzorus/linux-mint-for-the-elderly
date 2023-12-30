#!/bin/bash

# Installation of prerequisites, including a DNS server
# Installation des prérequis et d'un serveur DNS local
echo "Prerequisites installation..."
apt update
apt install -y dnsmasq curl

# Configuration du serveur DNS
# DNS server configuration
echo "Creating /etc/dnsmasq.conf..."
touch /etc/dnsmasq.conf
echo "domain-needed
bogus-priv
cache-size=1000
resolv-file=/etc/resolv.dnsmasq
strict-order
conf-file=/etc/dnsmasq-hosts.conf
expand-hosts" >> /etc/dnsmasq.conf

# Setting DNS providers to Cloudflare and Quad9
# To block pornographic sites, change 1.1.1.2 to 1.1.1.3 and 1.0.0.2 to 1.0.0.3
# Paramétrage des fournisseurs DNS : Cloudflare et Quad9
# Pour bloquer les contenus pornographiques, changer 1.1.1.2 en 1.1.1.3 et 1.0.0.2 en 1.0.0.3
echo "Creating /etc/resolv.dnsmasq..."
touch /etc/resolv.dnsmasq
echo "nameserver 1.1.1.2
nameserver 9.9.9.9
nameserver 1.0.0.2" >> /etc/resolv.dnsmasq

# Creating a blacklist building script from multiple sources
# Création d'un script de constitution de la liste noire à partir de plusieurs sources
echo "Creating /root/dns-blacklist-update.sh..."
cat <<EOF > /root/dns-blacklist-update.sh
#!/bin/bash
# Blacklist dedicated to ads and trackers
curl -SLso /etc/dnsmasq-hosts.conf https://raw.githubusercontent.com/notracking/hosts-blocklists/master/dnsmasq/dnsmasq.blacklist.txt

# Blacklist dedicated to typosquatting
curl -O https://dl.red.flag.domains/red.flag.domains.txt
sed -i '1,2d' red.flag.domains.txt
sed -i 's/^/address=\//' red.flag.domains.txt
sed -i 's/$/\//' red.flag.domains.txt
cat red.flag.domains.txt >> /etc/dnsmasq-hosts.conf
rm red.flag.domains.txt

systemctl restart dnsmasq
EOF

chmod +x /root/dns-blacklist-update.sh

# Creating an anacron task to run this script once a week
# Création d'une tâche anacron pour lancer ce script une fois par semaine
echo "Setting ANACRON to run dns-blacklist-update.sh once a week..."
echo -e "7\t3\tDNS_blacklist_update\t/root/dns-blacklist-update.sh" >> /etc/anacrontab

# Run this script for the first time
# Lancer le script une première fois
/root/dns-blacklist-update.sh

# Stopping and deactivating default resolver
# Arrêt et désactivation du résolveur par défaut
echo "Stopping and deactivating old resolver for good..."
systemctl stop systemd-resolved
sed -i 's/\[main\]/\[main\]\nrc-manager=unmanaged/' /etc/NetworkManager/NetworkManager.conf
sed -i 's/dns=default/dns=none/' /etc/NetworkManager/NetworkManager.conf
echo "DNSStubListener=no" >> /etc/systemd/resolved.conf
systemctl disable systemd-resolved
rm /etc/resolv.conf

# Start new resolver
# Démarrage du nouveau service DNS
echo "Running new resolver..."
systemctl restart dnsmasq

