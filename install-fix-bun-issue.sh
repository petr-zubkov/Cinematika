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
    echo "Usage: $0 domain user ip repository"
    exit 1
fi

DOMAIN="$1"
SSH_USER="$2"
SERVER_IP="$3"
GIT_REPO="$4"

log_info "Installing on server $SERVER_IP"
log_info "Domain: $DOMAIN"

# Create fixed server install script that addresses bun/tsx issue
cat > /tmp/server-setup.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "=== Starting fixed server setup (bun/tsx issue resolved) ==="

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "=== Updating system ==="
apt-get update
apt-get upgrade -y

echo "=== Removing conflicting Node.js packages ==="
apt-get remove --purge nodejs npm -y || true
apt-get autoremove -y || true
apt-get clean || true

echo "=== Removing old Node.js repositories ==="
rm -f /etc/apt/sources.list.d/nodesource.list || true
rm -f /etc/apt/keyrings/nodesource.gpg || true

echo "=== Installing NVM (Node Version Manager) ==="
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

echo "=== Installing Node.js 20 ==="
nvm install 20
nvm use 20
nvm alias default 20

echo "=== Verifying Node.js installation ==="
node --version
npm --version

echo "=== Installing PM2 ==="
npm install -g pm2

echo "=== Installing tsx globally ==="
npm install -g tsx

echo "=== Installing other required packages ==="
apt-get install -y git nginx build-essential ufw

echo "=== Setting up project directory ==="
mkdir -p /var/www/your-project-name
cd /var/www/your-project-name

echo "=== Cloning repository ==="
if [ -d ".git" ]; then
    echo "Repository already exists, pulling latest changes..."
    git pull origin main || git pull origin master
else
    echo "Cloning fresh repository..."
    git clone "$1" .
fi

echo "=== Checking package.json for bun references ==="
if grep -q "bun" package.json 2>/dev/null; then
    echo "Found bun references in package.json, creating backup and fixing..."
    cp package.json package.json.backup
    # Replace bun with node/npm in package.json
    sed -i 's/"bun":/\"node\":/g' package.json
    sed -i 's/"bun "/\"npm \"/g' package.json
    echo "package.json updated to use node/npm instead of bun"
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

echo "=== Creating PM2 configuration with Node.js interpreter ==="
mkdir -p logs
cat > ecosystem.config.js << 'ECOSYS'
module.exports = {
  apps: [{
    name: 'nextjs-app',
    script: 'server.ts',
    instances: 1,
    exec_mode: 'fork',
    interpreter: 'node',
    node_args: '-r tsx/register',
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

echo "=== Alternative PM2 configuration with tsx interpreter ==="
cat > ecosystem.config.tsx.js << 'ECOSYS'
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
# Try the node configuration first
if pm2 start ecosystem.config.js; then
    echo "PM2 started successfully with Node.js interpreter"
else
    echo "Node.js interpreter failed, trying tsx interpreter..."
    # Try the tsx configuration
    if pm2 start ecosystem.config.tsx.js; then
        echo "PM2 started successfully with tsx interpreter"
    else
        echo "PM2 start failed, trying direct npm start..."
        npm start &
    fi
fi

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
echo "=== To manage your application: ==="
echo "  pm2 status"
echo "  pm2 logs"
echo "  pm2 restart nextjs-app"
echo "  pm2 stop nextjs-app"
echo "  pm2 delete nextjs-app"
SCRIPT

# Copy script to server
echo "Copying installation script to server..."
scp /tmp/server-setup.sh "$SSH_USER@$SERVER_IP:/tmp/setup.sh" || {
    echo "Failed to copy script to server"
    exit 1
}

# Execute installation script
echo "Executing installation on server..."
ssh "$SSH_USER@$SERVER_IP" "chmod +x /tmp/setup.sh && sudo /tmp/setup.sh '$GIT_REPO'"

# Clean up
rm -f /tmp/server-setup.sh

echo "=== Installation completed! ==="
echo "Your site should be available at: http://$DOMAIN"
echo "To manage your server:"
echo "  ssh $SSH_USER@$SERVER_IP"
echo "  pm2 status"
echo "  pm2 logs"
echo "  sudo systemctl status nginx"