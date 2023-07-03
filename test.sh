#!/bin/bash

# Log file path
LOG_FILE="deploy.log"

# Function to log messages to a log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

# Function to display error message and exit
exit_with_error() {
    log "Error: $1"
    exit 1
}

# Remote machine details
REMOTE_USER="your_username"
REMOTE_HOST="remote_hostname_or_ip"

# Configure DNS
DNS_ENTRY="nameserver 10.250.210.1"
if ! ssh "$REMOTE_USER@$REMOTE_HOST" "grep -qF '$DNS_ENTRY' /etc/resolv.conf"; then
    log "Configuring DNS..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "echo '$DNS_ENTRY' | sudo tee -a /etc/resolv.conf >/dev/null" || exit_with_error "Failed to configure DNS."
else
    log "DNS already configured."
fi

# Install required packages
PACKAGES=("httpd" "firewalld" "git-all")
for package in "${PACKAGES[@]}"; do
    if ! ssh "$REMOTE_USER@$REMOTE_HOST" "rpm -q $package >/dev/null 2>&1"; then
        log "Installing $package..."
        ssh "$REMOTE_USER@$REMOTE_HOST" "sudo yum install -y $package" || exit_with_error "Failed to install $package."
    else
        log "$package already installed."
    fi
done

# Configure firewalld
if ! ssh "$REMOTE_USER@$REMOTE_HOST" "sudo firewall-cmd --list-all" | grep -qF "http"; then
    log "Configuring firewalld..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "sudo firewall-cmd --permanent --add-service=http" || exit_with_error "Failed to configure firewalld."
    ssh "$REMOTE_USER@$REMOTE_HOST" "sudo firewall-cmd --reload" || exit_with_error "Failed to reload firewalld."
else
    log "Firewalld already configured."
fi

# Clone git repo
REPO_URL="https://github.com/darrylkelly88/alexaweb.git"
REPO_PATH="/root/alexa-demo"
if ! ssh "$REMOTE_USER@$REMOTE_HOST" "[ ! -d $REPO_PATH ]"; then
    log "Cloning git repo..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "git clone $REPO_URL $REPO_PATH" || exit_with_error "Failed to clone git repo."
else
    log "Git repo already cloned."
fi

# Copy website assets to /var/www/html
ASSETS_SRC="/root/alexa-demo/alexa_demo_web/assets/"
ASSETS_DEST="/var/www/html/assets"
if ! ssh "$REMOTE_USER@$REMOTE_HOST" "[ ! -d $ASSETS_DEST ]"; then
    log "Copying website assets..."
    ssh "$REMOTE_USER@$REMOTE_HOST" "sudo cp -R $ASSETS_SRC $ASSETS_DEST" || exit_with_error "Failed to copy website assets."
    ssh "$REMOTE_USER@$REMOTE_HOST" "sudo chown -R apache:apache $ASSETS_DEST" || exit_with_error "Failed to set ownership of website assets."
    ssh "$REMOTE_USER@$REMOTE_HOST" "sudo chmod -R g+w $ASSETS_DEST" || exit_with_error "Failed to set permissions of website assets."
    ssh "$REMOTE_USER@$REMOTE_HOST" "sudo chcon -R -t httpd_sys_content_t $ASSETS_DEST" || exit_with_error "Failed to set SELinux context of website assets."
else
    log "Website assets already copied."
fi

# Display success message
log "Deployment completed successfully."
