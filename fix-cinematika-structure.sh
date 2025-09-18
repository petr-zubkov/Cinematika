#!/bin/bash

echo "=== Cinematika Structure Fix Script ==="

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in current directory"
    echo "Please run this script from the project root"
    exit 1
fi

echo "📍 Current directory: $(pwd)"
echo "📋 Current structure:"
ls -la

echo "🔍 Looking for app directory..."
find . -name "app" -type d

echo "🔍 Checking config directory..."
if [ -d "config" ]; then
    echo "📋 Config directory contents:"
    ls -la config/
    
    if [ -d "config/app" ]; then
        echo "✅ Found app in config directory"
        
        echo "🚀 Moving app from config to root..."
        mv config/app .
        
        echo "🚀 Moving other important directories from config..."
        # Move components if exists
        if [ -d "config/components" ]; then
            mv config/components .
            echo "✅ Moved components directory"
        fi
        
        # Move lib if exists
        if [ -d "config/lib" ]; then
            mv config/lib .
            echo "✅ Moved lib directory"
        fi
        
        # Move styles if exists
        if [ -d "config/styles" ]; then
            mv config/styles .
            echo "✅ Moved styles directory"
        fi
        
        # Move hooks if exists
        if [ -d "config/hooks" ]; then
            mv config/hooks .
            echo "✅ Moved hooks directory"
        fi
        
        echo "📋 Structure after moving:"
        ls -la
        
        # Check if we have app directory now
        if [ -d "app" ]; then
            echo "✅ app directory is now in root"
            
            # Check app contents
            echo "📋 App directory contents:"
            ls -la app/
            
            # Create basic next.config.js if not exists
            if [ ! -f "next.config.js" ] && [ ! -f "next.config.ts" ] && [ ! -f "next.config.mjs" ]; then
                echo "⚠️  Creating basic next.config.js..."
                cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
}

module.exports = nextConfig
EOF
                echo "✅ Created next.config.js"
            fi
            
            echo "🚀 Trying to build..."
            npm run build
            
            if [ $? -eq 0 ]; then
                echo "✅ Build successful!"
                
                echo "🚀 Starting application..."
                pm2 start server.ts --name nextjs-app || {
                    echo "⚠️  PM2 start failed, trying direct start..."
                    npm start &
                }
                
                echo "✅ Application started!"
                echo "📊 Check status with: pm2 status"
                echo "📋 Check logs with: pm2 logs"
            else
                echo "❌ Build failed"
                echo "🔧 Please check the error messages above"
            fi
        else
            echo "❌ app directory still not found in root"
        fi
    else
        echo "❌ app directory not found in config"
        echo "🔍 Looking for app in other locations..."
        find . -name "app" -type d -not -path "./node_modules/*"
    fi
else
    echo "❌ config directory not found"
    echo "🔍 Looking for app directory in all locations..."
    find . -name "app" -type d -not -path "./node_modules/*"
fi

echo "=== Script completed ==="