#!/bin/bash
# ################################################################
# Auto-install livestream server (no domain/email version)
# ################################################################

if [ "$(id -u)" != "0" ]; then
    echo "THIS SCRIPT SHOULD BE RUN AS SUDO. Please try using: sudo bash $0"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

# Update repos and install base tools
sudo apt-get update -y
sudo apt-get install curl dnsutils wget unzip git jq -y

# Install required packages
if sudo apt install -y nginx software-properties-common dpkg-dev make gcc automake build-essential \
    python3 python3-pip zlib1g-dev libpcre3 libpcre3-dev libssl-dev libxslt1-dev libxml2-dev \
    libgd-dev libgeoip-dev libgoogle-perftools-dev libperl-dev pkg-config autotools-dev gpac \
    ffmpeg mediainfo mencoder lame libvorbisenc2 libvorbisfile3 libx264-dev libvo-aacenc-dev \
    libmp3lame-dev libopus-dev libnginx-mod-rtmp mcrypt imagemagick memcached \
    php-common php-fpm php-gd php-cli php-cgi php-curl php-imagick php-zip php-mbstring php-pear; then
    echo "Package installation successful."
else
    echo "Error: Could not install packages. Exiting."
    exit 1
fi

# Configure PHP
sudo sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/8.1/fpm/php.ini

# Create folders
sudo mkdir -p /mnt/livestream/{hls,keys,dash,rec} /var/www/web

# Replace nginx.conf
[ -f /etc/nginx/nginx.conf ] && sudo rm /etc/nginx/nginx.conf
if sudo cp "conf/nginx.conf" "/etc/nginx/nginx.conf"; then
    echo "nginx.conf copied successfully."
else
    echo "Error: Could not copy nginx.conf. Exiting."
    exit 1
fi

# Remove default vhost
sudo rm -f "/etc/nginx/sites-enabled/default"

# Clone RTMP module and copy stat.xsl + webfiles
if sudo git clone https://github.com/arut/nginx-rtmp-module /usr/src/nginx-rtmp-module; then
    sudo cp /usr/src/nginx-rtmp-module/stat.xsl /var/www/web/stat.xsl
    sudo cp -r "webfiles/." "/var/www/web"
else
    echo "Error: Could not copy required files. Exiting."
    exit 1
fi

# Permissions
sudo chown -R www-data: /var/www/web /mnt/livestream

# Install Certbot (optional, but no domain/email used here)
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Generate DH params
sudo openssl dhparam -out /etc/nginx/ssl-dhparams.pem 4096
if [ -f /etc/nginx/ssl-dhparams.pem ]; then
    echo "DH parameters file generated successfully."
else
    echo "Error: DH parameters could not be generated. Exiting."
    exit 1
fi

# Restore sudoers
echo "$USER ALL=(ALL) ALL" | sudo tee -a /etc/sudoers > /dev/null

echo "Installation complete! Configure your vhost manually in /etc/nginx/sites-available if needed."
