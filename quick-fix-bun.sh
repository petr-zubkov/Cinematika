#!/bin/bash
# Quick fix for bun interpreter issue
# Usage: curl -sSL https://your-domain.com/quick-fix-bun.sh | bash -s -- server-ip

if [ $# -eq 0 ]; then
    echo "Usage: $0 server-ip"
    echo "Example: $0 95.81.117.109"
    exit 1
fi

SERVER_IP="$1"
SSH_USER="root"

echo "=== Quick Fix for Bun/TSX Issue ==="
echo "Server: $SERVER_IP"
echo "User: $SSH_USER"

# Create the fix script
cat > /tmp/fix-bun.sh << 'FIXSCRIPT'
#!/bin/bash
set -e

echo "=== Fixing Bun/TSX Issue ==="

# Navigate to project directory
cd /var/www/kinoclub.com.ru || {
    echo "Project directory not found, trying /var/www/your-project-name..."
    cd /var/www/your-project-name || {
        echo "Cannot find project directory"
        exit 1
    }
}

echo "Current directory: $(pwd)"

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "package.json not found in current directory"
    exit 1
fi

# Create backup of package.json
echo "Creating backup of package.json..."
cp package.json package.json.backup.$(date +%Y%m%d_%H%M%S)

# Fix bun references in package.json
echo "Fixing bun references in package.json..."
if grep -q "bun" package.json; then
    sed -i 's/"bun":/\"node\":/g' package.json
    sed -i 's/"bun "/\"npm \"/g' package.json
    echo "package.json updated"
else
    echo "No bun references found in package.json"
fi

# Install tsx globally if not already installed
echo "Installing tsx globally..."
npm install -g tsx || {
    echo "Failed to install tsx globally, trying local installation..."
    npm install tsx --save-dev
}

# Create PM2 configuration with Node.js + tsx
echo "Creating PM2 configuration..."
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

# Alternative configuration with tsx interpreter
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

# Stop existing PM2 process
echo "Stopping existing PM2 process..."
pm2 stop nextjs-app || true
pm2 delete nextjs-app || true

# Try to start with Node.js + tsx
echo "Starting application with Node.js + tsx..."
if pm2 start ecosystem.config.js; then
    echo "✅ Application started successfully with Node.js + tsx"
else
    echo "❌ Node.js + tsx failed, trying tsx interpreter..."
    
    # Try with tsx interpreter
    if pm2 start ecosystem.config.tsx.js; then
        echo "✅ Application started successfully with tsx interpreter"
    else
        echo "❌ tsx interpreter failed, trying npm start..."
        
        # Try npm start as last resort
        npm start &
        sleep 5
        
        # Check if process is running
        if pgrep -f "node.*server.ts" > /dev/null; then
            echo "✅ Application started with npm start"
        else
            echo "❌ All startup methods failed"
            exit 1
        fi
    fi
fi

# Save PM2 configuration
pm2 save || echo "PM2 save failed (this is normal if not running as root)"

echo "=== Fix completed ==="
echo "=== Checking status ==="
pm2 status
echo "=== Recent logs ==="
pm2 logs --lines 20
FIXSCRIPT

# Copy the fix script to the server
echo "Copying fix script to server..."
scp /tmp/fix-bun.sh "$SSH_USER@$SERVER_IP:/tmp/fix-bun.sh" || {
    echo "Failed to copy fix script to server"
    exit 1
}

# Execute the fix script
echo "Executing fix on server..."
ssh "$SSH_USER@$SERVER_IP" "chmod +x /tmp/fix-bun.sh && /tmp/fix-bun.sh"

# Clean up
rm -f /tmp/fix-bun.sh

echo "=== Quick fix completed! ==="
echo "Check your application at: http://kinoclub.com.ru"
echo "To manage: ssh $SSH_USER@$SERVER_IP"
echo "Then run: pm2 status"