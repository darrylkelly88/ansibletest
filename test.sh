#!/bin/bash

set -e

# Function to display error message and exit
exit_with_error() {
    echo "Error: $1"
    exit 1
}

# Configure DNS
DNS_ENTRY="nameserver 10.250.210.1"
if ! grep -qF "$DNS_ENTRY" /etc/resolv.conf; then
    echo "$DNS_ENTRY" >> /etc/resolv.conf || exit_with_error "Failed to configure DNS."
else
    echo "DNS already configured."
fi

# Install required packages
PACKAGES=("httpd" "firewalld" "git-all")
for package in "${PACKAGES[@]}"; do
    if ! rpm -q "$package" >/dev/null 2>&1; then
        yum install -y "$package" || exit_with_error "Failed to install $package."
    else
        echo "$package already installed."
    fi
done

# Configure firewalld
if ! firewall-cmd --list-all | grep -qF "http"; then
    firewall-cmd --permanent --add-service=http || exit_with_error "Failed to configure firewalld."
    firewall-cmd --reload || exit_with_error "Failed to reload firewalld."
else
    echo "Firewalld already configured."
fi

# Clone git repo
REPO_URL="https://github.com/darrylkelly88/alexaweb.git"
REPO_PATH="/root/alexa-demo"
if [ ! -d "$REPO_PATH" ]; then
    git clone "$REPO_URL" "$REPO_PATH" || exit_with_error "Failed to clone git repo."
else
    echo "Git repo already cloned."
fi

# Copy website assets to /var/www/html
ASSETS_SRC="/root/alexa-demo/alexa_demo_web/assets/"
ASSETS_DEST="/var/www/html/assets"
if [ ! -d "$ASSETS_DEST" ]; then
    cp -R "$ASSETS_SRC" "$ASSETS_DEST" || exit_with_error "Failed to copy website assets."
    chown -R apache:apache "$ASSETS_DEST" || exit_with_error "Failed to set ownership of website assets."
    chmod -R g+w "$ASSETS_DEST" || exit_with_error "Failed to set permissions of website assets."
    chcon -R -t httpd_sys_content_t "$ASSETS_DEST" || exit_with_error "Failed to set SELinux context of website assets."
else
    echo "Website assets already copied."
fi

# Display success message
echo "Deployment completed successfully."
