#!/bin/bash

apt install -y curl

# Download latest version of RustDesk and install it
# Télécharger la dernière version de RustDesk et l'installer
curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
| grep "browser_download_url" \
| grep "x86_64.deb" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi -

apt install -y ./rustdesk*x86_64.deb

# If mate desktop, RustDesk does not appear in the menu
# With Cinnamon, it automatically appears.
