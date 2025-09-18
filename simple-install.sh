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

# Create install script
cat > /tmp/server-install.sh << 'EOF'
#!/bin/bash
set -e

echo "=== Starting installation ==="

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget git nginx build-essential

# Install Node.js 20
echo "=== Installing Node.js ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install PM2
echo "=== Installing PM2 ==="
npm install -g pm2

# Create project directory
echo "=== Creating project directory ==="
mkdir -p /var/www/your-project-name
cd /var/www/your-project-name

# Clone repository
echo "=== Cloning repository ==="
git clone "$1" .

# Install dependencies
echo "=== Installing dependencies ==="
npm install

# Setup database if exists
if [ -f "prisma/schema.prisma" ]; then
    echo "=== Setting up database ==="
    npx prisma generate
    npx prisma db push
fi

# Build project
echo "=== Building project ==="
npm run build

# Create PM2 config
echo "=== Creating PM2 config ==="
cat > ecosystem.config.js << 'EOL'
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
EOL

# Create logs directory
mkdir -p logs

# Start application
echo "=== Starting application ==="
pm2 start ecosystem.config.js
pm2 save
pm2 startup || true

# Setup Nginx
echo "=== Setting up Nginx ==="
cat > /etc/nginx/sites-available/your-domain << 'EOL'
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
EOL

# Enable site
ln -sf /etc/nginx/sites-available/your-domain /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t && systemctl restart nginx

# Setup firewall
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# Create .env file
if [ ! -f ".env" ]; then
    cat > .env << EOENV
NODE_ENV=production
DATABASE_URL="file:./dev.db"
NEXTAUTH_SECRET=$(openssl rand -base64 32)
NEXTAUTH_URL=http://localhost:3000
EOENV
fi

echo "=== Installation completed ==="
echo "=== Checking services ==="
pm2 status
systemctl status nginx --no-pager -l
echo "=== Your site should be available at http://localhost ==="
EOF

# Copy and execute on server
echo "=== Copying install script to server ==="
scp /tmp/server-install.sh "$SSH_USER@$SERVER_IP:/tmp/install.sh"

echo "=== Executing installation on server ==="
ssh "$SSH_USER@$SERVER_IP" "chmod +x /tmp/install.sh && sudo /tmp/install.sh '$GIT_REPO'"

# Clean up
rm -f /tmp/server-install.sh

log_info "=== Installation completed! ==="
log_info "Your site should be available at: http://$DOMAIN"
log_info "To manage your server:"
echo "  ssh $SSH_USER@$SERVER_IP"
echo "  pm2 status"
echo "  pm2 logs"