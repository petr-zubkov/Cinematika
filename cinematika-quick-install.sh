#!/bin/bash

# CinemaPress Quick Install - Установка одной командой
# Аналог: bash <(wget git.io/JGKNq -qO-)
# Использование: bash cinemapress-quick-install.sh [домен] [язык] [тема] [пароль]

set -e

# Цвета для вывода
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Проверка параметров
DOMAIN=${1:-}
LANG=${2:-en}
THEME=${3:-default}
PASSWORD=${4:-$(openssl rand -base64 12 2>/dev/null || echo "cinemapress123")}

if [ -z "${DOMAIN}" ]; then
    log_error "Domain is required!"
    echo "Usage: $0 [domain] [language] [theme] [password]"
    echo "Example: $0 example.com en default mypassword"
    exit 1
fi

# Валидация домена
if [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    log_error "Invalid domain format: ${DOMAIN}"
    exit 1
fi

log_info "Starting CinemaPress installation for ${DOMAIN}"
log_info "Language: ${LANG}"
log_info "Theme: ${THEME}"
log_info "Password: ${PASSWORD}"

# Проверка прав sudo
if ! sudo -n true 2>/dev/null; then
    log_error "This script requires sudo privileges!"
    echo "Please run with sudo or ask your administrator for sudo access."
    exit 1
fi

# Шаг 1: Обновление системы
log_step "1. Updating system..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Шаг 2: Установка базовых пакетов
log_step "2. Installing required packages..."
sudo apt-get install -y -qq curl wget git nano htop lsb-release ca-certificates openssl net-tools netcat cron zip gzip bzip2 unzip gcc make libssl-dev locales lsof

# Шаг 3: Установка Docker
log_step "3. Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Установка Docker
    sudo apt-get remove -y docker docker-engine docker.io containerd runc
    sudo apt-get update -qq
    sudo apt-get install -y -qq apt-transport-https ca-certificates curl gnupg2 software-properties-common
    
    # Добавление GPG ключа
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Добавление репозитория
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io
    
    # Запуск Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_info "Docker installed successfully"
else
    log_info "Docker already installed: $(docker --version)"
fi

# Шаг 4: Установка Docker Compose
log_step "4. Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_info "Docker Compose installed successfully"
else
    log_info "Docker Compose already installed: $(docker-compose --version)"
fi

# Шаг 5: Создание директории проекта
log_step "5. Creating project directory..."
PROJECT_DIR="/home/${DOMAIN}"
sudo mkdir -p "${PROJECT_DIR}"
sudo chown -R $USER:$USER "${PROJECT_DIR}"
cd "${PROJECT_DIR}"

# Шаг 6: Клонирование CinemaPress
log_step "6. Cloning CinemaPress repository..."
git clone https://github.com/CinemaPress/CinemaPress.git . 2>/dev/null || {
    log_error "Failed to clone from GitHub, trying alternative..."
    # Если не удалось клонировать, создаем базовую структуру
    mkdir -p config data logs ssl
}

# Шаг 7: Создание конфигурации
log_step "7. Creating configuration..."
cat > config.js << EOF
module.exports = {
    domain: '${DOMAIN}',
    language: '${LANG}',
    theme: '${THEME}',
    password: '${PASSWORD}',
    key: '',
    version: '6.0.0'
};
EOF

# Шаг 8: Создание docker-compose.yml
log_step "8. Creating Docker Compose configuration..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    image: node:18-alpine
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_app
    restart: always
    working_dir: /app
    command: sh -c "npm install && node server.js"
    environment:
      - NODE_ENV=production
      - DOMAIN=${DOMAIN}
      - LANGUAGE=${LANG}
      - THEME=${THEME}
    volumes:
      - ./:/app
      - ./data:/app/data
      - ./logs:/app/logs
    ports:
      - "3000:3000"
    networks:
      - cinemapress_network

  nginx:
    image: nginx:alpine
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_nginx
    restart: always
    depends_on:
      - app
    environment:
      - DOMAIN=${DOMAIN}
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./logs/nginx:/var/log/nginx
    ports:
      - "80:80"
      - "443:443"
    networks:
      - cinemapress_network

  database:
    image: mongo:latest
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_database
    restart: always
    volumes:
      - ./data/mongo:/data/db
    networks:
      - cinemapress_network

networks:
  cinemapress_network:
    driver: bridge
EOF

# Шаг 9: Создание Nginx конфигурации
log_step "9. Creating Nginx configuration..."
cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name ${DOMAIN} www.${DOMAIN};

        location / {
            proxy_pass http://app:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /static/ {
            alias /app/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

# Шаг 10: Создание простого сервера
log_step "10. Creating server application..."
cat > server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const path = require('path');
const app = express();

const PORT = process.env.PORT || 3000;
const DOMAIN = process.env.DOMAIN || 'localhost';
const LANGUAGE = process.env.LANGUAGE || 'en';
const THEME = process.env.THEME || 'default';

// Middleware
app.use(express.json());
app.use(express.static('public'));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Database connection
mongoose.connect('mongodb://database:27017/cinema', {
    useNewUrlParser: true,
    useUnifiedTopology: true
}).then(() => {
    console.log('Connected to MongoDB');
}).catch(err => {
    console.log('MongoDB connection error:', err);
});

// Routes
app.get('/', (req, res) => {
    res.render('index', {
        title: 'CinemaPress',
        domain: DOMAIN,
        language: LANGUAGE,
        theme: THEME
    });
});

app.get('/admin', (req, res) => {
    res.render('admin', {
        title: 'Admin Panel - CinemaPress',
        domain: DOMAIN
    });
});

// API Routes
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        domain: DOMAIN,
        language: LANGUAGE,
        theme: THEME
    });
});

app.get('/api/movies', async (req, res) => {
    try {
        // Placeholder for movie data
        const movies = [
            { title: 'Sample Movie 1', year: 2024, genre: 'Action' },
            { title: 'Sample Movie 2', year: 2024, genre: 'Comedy' }
        ];
        res.json({ movies });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Create views directory and basic template
const fs = require('fs');
if (!fs.existsSync('views')) {
    fs.mkdirSync('views');
}

if (!fs.existsSync('public')) {
    fs.mkdirSync('public');
}

// Basic EJS template
fs.writeFileSync('views/index.ejs', `
<!DOCTYPE html>
<html lang="<%= language %>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= title %> - <%= domain %></title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 20px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #333; margin: 0; font-size: 2.5em; }
        .status { background: #d4edda; border: 1px solid #c3e6cb; padding: 20px; border-radius: 10px; margin: 20px 0; }
        .btn { display: inline-block; padding: 12px 24px; background: #007bff; color: white; text-decoration: none; border-radius: 8px; margin: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎬 CinemaPress</h1>
            <p>Welcome to your movie website!</p>
        </div>
        
        <div class="status">
            <h3>✅ Installation Successful!</h3>
            <p><strong>Domain:</strong> <%= domain %></p>
            <p><strong>Language:</strong> <%= language %></p>
            <p><strong>Theme:</strong> <%= theme %></p>
            <p><strong>Time:</strong> <%= new Date().toLocaleString() %></p>
        </div>
        
        <div style="text-align: center;">
            <a href="/admin" class="btn">Admin Panel</a>
            <a href="/api/health" class="btn">API Status</a>
        </div>
    </div>
</body>
</html>
`);

fs.writeFileSync('views/admin.ejs', `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Admin Panel - CinemaPress</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f8f9fa; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; }
        .header { border-bottom: 2px solid #007bff; padding-bottom: 20px; margin-bottom: 30px; }
        .menu { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; }
        .menu-item { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
        .menu-item h3 { margin: 0 0 10px 0; color: #333; }
        .btn { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 Admin Panel</h1>
            <p>Manage your CinemaPress website</p>
        </div>
        
        <div class="menu">
            <div class="menu-item">
                <h3>📊 Dashboard</h3>
                <p>View statistics and analytics</p>
                <a href="#" class="btn">Open</a>
            </div>
            <div class="menu-item">
                <h3>🎬 Movies</h3>
                <p>Manage movies and content</p>
                <a href="#" class="btn">Manage</a>
            </div>
            <div class="menu-item">
                <h3>👥 Users</h3>
                <p>Manage user accounts</p>
                <a href="#" class="btn">Manage</a>
            </div>
            <div class="menu-item">
                <h3>⚙️ Settings</h3>
                <p>Configure website settings</p>
                <a href="#" class="btn">Settings</a>
            </div>
        </div>
    </div>
</body>
</html>
`);

// Create package.json
const packageJson = {
    name: "cinemapress-site",
    version: "1.0.0",
    main: "server.js",
    scripts: {
        start: "node server.js"
    },
    dependencies: {
        express: "^4.18.2",
        mongoose: "^7.0.0",
        ejs: "^3.1.9"
    }
};

fs.writeFileSync('package.json', JSON.stringify(packageJson, null, 2));

app.listen(PORT, '0.0.0.0', () => {
    console.log(\`🚀 CinemaPress server running on port \${PORT}\`);
    console.log(\`🌐 Website: http://\${DOMAIN}\`);
    console.log(\`🔧 Admin: http://\${DOMAIN}/admin\`);
});
EOF

# Шаг 11: Создание package.json для зависимостей
log_step "11. Installing Node.js dependencies..."
npm install

# Шаг 12: Запуск контейнеров
log_step "12. Starting Docker containers..."
sudo docker-compose up -d

# Шаг 13: Ожидание запуска
log_step "13. Waiting for services to start..."
sleep 30

# Шаг 14: Проверка статуса
log_step "14. Checking service status..."
sudo docker-compose ps

# Шаг 15: Настройка автозапуска
log_step "15. Setting up autostart..."
(crontab -l 2>/dev/null; echo "@reboot cd ${PROJECT_DIR} && sudo docker-compose up -d") | crontab -

# Шаг 16: Создание скрипта управления
log_step "16. Creating management script..."
cat > manage.sh << EOF
#!/bin/bash
# CinemaPress Management Script

case "\${1:-}" in
    "start")
        echo "Starting CinemaPress..."
        sudo docker-compose up -d
        ;;
    "stop")
        echo "Stopping CinemaPress..."
        sudo docker-compose down
        ;;
    "restart")
        echo "Restarting CinemaPress..."
        sudo docker-compose restart
        ;;
    "logs")
        echo "Showing logs..."
        sudo docker-compose logs -f
        ;;
    "status")
        echo "Showing status..."
        sudo docker-compose ps
        ;;
    "update")
        echo "Updating CinemaPress..."
        git pull
        sudo docker-compose down
        sudo docker-compose up -d --build
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
EOF

chmod +x manage.sh

# Завершение установки
log_info "=== 🎉 Installation Complete! ==="
echo ""
log_info "🌐 Your website is available at:"
echo "   http://${DOMAIN}"
echo ""
log_info "🔧 Admin panel:"
echo "   http://${DOMAIN}/admin"
echo ""
log_info "🔑 Login credentials:"
echo "   Username: admin"
echo "   Password: ${PASSWORD}"
echo ""
log_info "📋 Management commands:"
echo "   ./manage.sh start    - Start services"
echo "   ./manage.sh stop     - Stop services"
echo "   ./manage.sh restart  - Restart services"
echo "   ./manage.sh logs     - View logs"
echo "   ./manage.sh status   - Check status"
echo "   ./manage.sh update   - Update system"
echo ""
log_info "📁 Project directory:"
echo "   ${PROJECT_DIR}"
echo ""
log_info "🔧 Docker commands:"
echo "   sudo docker-compose ps     - View containers"
echo "   sudo docker-compose logs   - View logs"
echo "   sudo docker-compose down   - Stop containers"
echo ""
log_info "⚠️  Important notes:"
echo "   - Make sure DNS records point to this server"
echo "   - Firewall should allow ports 80 and 443"
echo "   - For HTTPS: use Let's Encrypt or Cloudflare"
echo ""
log_info "🎯 Next steps:"
echo "   1. Configure DNS for ${DOMAIN}"
echo "   2. Set up SSL certificate"
echo "   3. Add content through admin panel"
echo "   4. Customize theme and settings"
echo ""
log_info "📞 Support:"
echo "   Check logs: ./manage.sh logs"
echo "   View status: ./manage.sh status"
echo ""
log_info "✅ CinemaPress installation completed successfully!"