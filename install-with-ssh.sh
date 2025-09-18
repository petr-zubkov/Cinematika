#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ $# -lt 3 ]; then
    log_error "Usage: $0 domain user ip repository"
    echo "Example: $0 example.com admin 192.168.1.100 https://github.com/user/repo.git"
    exit 1
fi

DOMAIN="$1"
SSH_USER="$2"
SERVER_IP="$3"
GIT_REPO="$4"

log_info "Installing on server $SERVER_IP"
log_info "Domain: $DOMAIN"
log_info "SSH User: $SSH_USER"

# Test SSH connection first
log_info "Testing SSH connection..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    log_warn "SSH connection failed. Let's check available users..."
    
    # Try common users
    for user in root admin ubuntu deploy; do
        if ssh -o BatchMode=yes -o ConnectTimeout=3 "$user@$SERVER_IP" "echo 'Found user: $user'" 2>/dev/null; then
            log_info "Found working user: $user"
            SSH_USER="$user"
            break
        fi
    done
    
    if [ "$SSH_USER" != "$2" ]; then
        log_info "Using user: $SSH_USER instead of $2"
    fi
    
    # If still no connection, ask for manual setup
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "echo 'SSH connection successful'" 2>/dev/null; then
        log_error "Could not establish SSH connection"
        log_info "Please ensure:"
        echo "1. User $SSH_USER exists on server $SERVER_IP"
        echo "2. SSH access is enabled"
        echo "3. You have the correct credentials"
        echo "4. Try manually: ssh $SSH_USER@$SERVER_IP"
        exit 1
    fi
fi

log_info "SSH connection successful with user: $SSH_USER"

# Create server install script
cat > /tmp/server-setup.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "=== Starting server setup ==="

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "=== Updating system ==="
apt-get update
apt-get upgrade -y

echo "=== Installing required packages ==="
apt-get install -y curl wget git nginx build-essential ufw

echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "=== Installing PM2 ==="
npm install -g pm2

echo "=== Setting up project directory ==="
mkdir -p /var/www/your-project-name
cd /var/www/your-project-name

echo "=== Cloning repository ==="
# Remove existing directory if it exists
if [ -d ".git" ]; then
    echo "Repository already exists, pulling latest changes..."
    git pull origin main || git pull origin master
else
    echo "Cloning fresh repository..."
    git clone "$1" .
fi

echo "=== Installing dependencies ==="
npm install

echo "=== Setting up database (if exists) ==="
if [ -f "prisma/schema.prisma" ]; then
    npx prisma generate
    npx prisma db push
fi

echo "=== Building project ==="
npm run build

echo "=== Creating PM2 configuration ==="
mkdir -p logs
cat > ecosystem.config.js << 'ECOSYS'
module.exports = {
  apps: [{
    name: 'nextjs-app',
    script: 'server.ts',
    instances: 1,
    exec_mode: 'fork',
    interpreter: 'tsx',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
ECOSYS

echo "=== Starting application with PM2 ==="
pm2 start ecosystem.config.js || {
    echo "PM2 start failed, trying direct start..."
    npm start &
}

pm2 save
pm2 startup || echo "PM2 startup setup failed (this is normal if not running as root)"

echo "=== Setting up Nginx ==="
cat > /etc/nginx/sites-available/your-domain << 'NGINX'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /api/socketio/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /_next/static/ {
        alias /var/www/your-project-name/.next/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    client_max_body_size 100M;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
}
NGINX

# Enable site
ln -sf /etc/nginx/sites-available/your-domain /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test Nginx configuration
if nginx -t; then
    systemctl restart nginx
    echo "Nginx restarted successfully"
else
    echo "Nginx configuration test failed, keeping previous config"
fi

echo "=== Setting up firewall ==="
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

echo "=== Creating environment file ==="
if [ ! -f ".env" ]; then
    cat > .env << 'ENV'
NODE_ENV=production
DATABASE_URL="file:./dev.db"
NEXTAUTH_SECRET=$(openssl rand -base64 32)
NEXTAUTH_URL=http://localhost:3000
ENV
fi

echo "=== Installation completed successfully ==="
echo "=== Service Status ==="
pm2 status
systemctl status nginx --no-pager -l
echo "=== Your application should be accessible at: ==="
echo "  Local: http://localhost:3000"
echo "  Via Nginx: http://$(hostname -I | awk '{print $1}')"
SCRIPT

# Copy script to server
log_info "Copying installation script to server..."
scp /tmp/server-setup.sh "$SSH_USER@$SERVER_IP:/tmp/setup.sh" || {
    log_error "Failed to copy script to server"
    exit 1
}

# Execute installation script
log_info "Executing installation on server..."
ssh "$SSH_USER@$SERVER_IP" "chmod +x /tmp/setup.sh && sudo /tmp/setup.sh '$GIT_REPO'"

# Clean up
rm -f /tmp/server-setup.sh

log_info "=== Installation completed! ==="
log_info "Your site should be available at: http://$DOMAIN"
log_info "To manage your server:"
echo "  ssh $SSH_USER@$SERVER_IP"
echo "  pm2 status"
echo "  pm2 logs"
echo "  sudo systemctl status nginx"