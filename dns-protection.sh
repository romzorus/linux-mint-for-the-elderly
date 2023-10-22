#!/bin/bash

# This part adds a protection through DNS filtering :
#   1. install own local DNS server
#   2. switch to DNS providers that block malicious domains
#   3. add a blacklist (typosquatting, ads, trackers) and regularly update it


echo "Prerequisites installation..."
apt update
apt install -y dnsmasq curl ipset

echo "Creating /etc/dnsmasq.conf..."
touch /etc/dnsmasq.conf
echo "domain-needed
bogus-priv
cache-size=1000
resolv-file=/etc/resolv.dnsmasq
strict-order
conf-file=/etc/dnsmasq-hosts.conf
expand-hosts" >> /etc/dnsmasq.conf

echo "Creating /etc/resolv.dnsmasq..."
touch /etc/resolv.dnsmasq
echo "nameserver 1.1.1.3
nameserver 9.9.9.9
nameserver 1.0.0.3" >> /etc/resolv.dnsmasq

echo "Stopping and deactivating old resolver..."
systemctl stop systemd-resolved
sed -i 's/\[main\]/\[main\]\nrc-manager=unmanaged/' /etc/NetworkManager/NetworkManager.conf
sed -i 's/dns=default/dns=none/' /etc/NetworkManager/NetworkManager.conf
echo "DNSStubListener=no" >> /etc/systemd/resolved.conf

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

echo "Setting ANACRON to run dns-blacklist-update.sh once a week..."
echo -e "7\t3\tDNS_blacklist_update\t/root/dns-blacklist-update.sh" >> /etc/anacrontab

echo "Temporarily starting old resolver to run dns-blacklist-update.sh for the first time..."

systemctl start systemd-resolved
/root/dns-blacklist-update.sh

echo "Finally disabling the old resolver for good..."
systemctl stop systemd-resolved
systemctl disable systemd-resolved
rm /etc/resolv.conf

echo "Running new resolver..."
systemctl restart dnsmasq

