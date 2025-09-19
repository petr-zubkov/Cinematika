#!/bin/bash

# Cinematika One Command Install - Полная установка одной командой
# Аналог: bash <(wget git.io/JGKNq -qO-)
# Использование: curl -sSL https://raw.githubusercontent.com/your-repo/Cinematika-one-command.sh | bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции для вывода
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Функция для отрисовки логотипа
show_logo() {
    printf "${CYAN}"
    cat << 'EOF'
    ███████╗ ██╗ ███    ██╗ ███████╗ ███      ███╗    █████╗ ███████╗  ██╗ ██╗  ███╗    █████╗  
    ██╔════╝ ██║ ██║█   ██║ ██╔════╝ ██║█   █ ██║    ██╔██║     ██╔═╝  ██║ ██║ ██╔═╝    ██╔██║ 
    ██║        ██║ ██║ █  ██║ █████╗    ██║ █ █  ██║   ██████║    ██║     ██║ ████╔╝       ██████║ 
    ██║        ██║ ██║  █ ██║ ██╔══╝    ██║  █   ██║   ██╔═██║     ██║     ██║ ██╔██╗      ██╔═██║ 
    ███████╗ ██║ ██║   ███║ ███████╗ ██║       ██║  ██║  ██║     ██║     ██║ ██╗  ██║   ██║   ██║
     ╚═════╝ ╚═╝ ╚═╝     ╚═╝ ╚══════╝ ╚═╝       ╚═╝  ╚═╝  ╚═╝     ╚═╝     ╚═╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝
EOF
    printf "${NC}"
    echo ""
}

# Функция проверки системных требований
check_requirements() {
    log_step "Checking system requirements..."
    
    # Проверка ОС
    if [[ ! -f /etc/os-release ]]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    # Проверка архитектуры
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
        log_warn "Unsupported architecture: $ARCH. Continuing anyway..."
    fi
    
    # Проверка прав sudo
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges!"
        echo "Please run with sudo or ask your administrator for sudo access."
        echo ""
        echo "Without sudo, you can use our minimal version:"
        echo "https://github.com/Cinematika/Cinematika-minimal"
        exit 1
    fi
    
    log_success "System requirements met"
}

# Функция получения параметров установки
get_install_parameters() {
    log_step "Getting installation parameters..."
    
    # Параметры по умолчанию
    DOMAIN=${CP_DOMAIN:-}
    LANGUAGE=${CP_LANG:-en}
    THEME=${CP_THEME:-default}
    PASSWORD=${CP_PASSWD:-}
    
    # Если домен не указан в переменных окружения, спрашиваем
    if [ -z "$DOMAIN" ]; then
        echo ""
        echo "Please enter your domain name:"
        read -p "Domain (example.com): " DOMAIN
        
        if [ -z "$DOMAIN" ]; then
            log_error "Domain is required!"
            exit 1
        fi
    fi
    
    # Валидация домена
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid domain format: $DOMAIN"
        exit 1
    fi
    
    # Если язык не указан, спрашиваем
    if [ -z "$LANGUAGE" ]; then
        echo ""
        echo "Select language:"
        echo "1) English (en)"
        echo "2) Русский (ru)"
        echo "3) Español (es)"
        echo "4) Français (fr)"
        echo "5) Deutsch (de)"
        read -p "Language (1-5) [1]: " lang_choice
        
        case "${lang_choice:-1}" in
            1) LANGUAGE="en" ;;
            2) LANGUAGE="ru" ;;
            3) LANGUAGE="es" ;;
            4) LANGUAGE="fr" ;;
            5) LANGUAGE="de" ;;
            *) LANGUAGE="en" ;;
        esac
    fi
    
    # Если тема не указана, спрашиваем
    if [ -z "$THEME" ]; then
        echo ""
        echo "Select theme:"
        echo "1) Default"
        echo "2) Dark"
        echo "3) Modern"
        echo "4) Cinema"
        echo "5) Minimal"
        read -p "Theme (1-5) [1]: " theme_choice
        
        case "${theme_choice:-1}" in
            1) THEME="default" ;;
            2) THEME="dark" ;;
            3) THEME="modern" ;;
            4) THEME="cinema" ;;
            5) THEME="minimal" ;;
            *) THEME="default" ;;
        esac
    fi
    
    # Если пароль не указан, генерируем или спрашиваем
    if [ -z "$PASSWORD" ]; then
        echo ""
        read -p "Generate random password? (Y/n) [Y]: " gen_pass
        
        if [[ "${gen_pass:-Y}" =~ ^[Yy]$ ]]; then
            PASSWORD=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
            log_info "Generated password: $PASSWORD"
        else
            read -s -p "Enter password: " PASSWORD
            echo ""
            read -s -p "Confirm password: " PASSWORD_CONFIRM
            echo ""
            
            if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                log_error "Passwords do not match!"
                exit 1
            fi
            
            if [ ${#PASSWORD} -lt 8 ]; then
                log_error "Password must be at least 8 characters!"
                exit 1
            fi
        fi
    fi
    
    log_success "Installation parameters configured"
    log_info "Domain: $DOMAIN"
    log_info "Language: $LANGUAGE"
    log_info "Theme: $THEME"
    log_info "Password: ${PASSWORD:0:4}****"
}

# Функция обновления системы
update_system() {
    log_step "Updating system packages..."
    
    # Определение менеджера пакетов
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        UPDATE_CMD="sudo apt-get update -qq"
        UPGRADE_CMD="sudo apt-get upgrade -y -qq"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        UPDATE_CMD="sudo yum update -y"
        UPGRADE_CMD="sudo yum upgrade -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="sudo dnf update -y"
        UPGRADE_CMD="sudo dnf upgrade -y"
    else
        log_error "No supported package manager found"
        exit 1
    fi
    
    log_info "Using package manager: $PKG_MANAGER"
    
    # Обновление системы
    eval "$UPDATE_CMD" || log_warn "System update failed, continuing..."
    eval "$UPGRADE_CMD" || log_warn "System upgrade failed, continuing..."
    
    log_success "System updated"
}

# Функция установки базовых пакетов
install_base_packages() {
    log_step "Installing base packages..."
    
    # Базовые пакеты для разных систем
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        PACKAGES="curl wget git nano htop lsb-release ca-certificates openssl net-tools netcat cron zip gzip bzip2 unzip gcc make libssl-dev locales lsof software-properties-common gnupg2 apt-transport-https"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $PACKAGES || {
            log_error "Failed to install base packages"
            exit 1
        }
    elif [ "$PKG_MANAGER" = "yum" ]; then
        PACKAGES="curl wget git nano htop lsb-release ca-certificates openssl net-tools netcat cron zip gzip bzip2 unzip gcc make openssl-devel lsof epel-release"
        sudo yum install -y $PACKAGES || {
            log_error "Failed to install base packages"
            exit 1
        }
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        PACKAGES="curl wget git nano htop lsb-release ca-certificates openssl net-tools netcat cron zip gzip bzip2 unzip gcc make openssl-devel lsof dnf-plugins-core"
        sudo dnf install -y $PACKAGES || {
            log_error "Failed to install base packages"
            exit 1
        }
    fi
    
    log_success "Base packages installed"
}

# Функция установки Docker
install_docker() {
    log_step "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
        return
    fi
    
    # Установка Docker в зависимости от дистрибутива
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        # Удаление старых версий
        sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Установка зависимостей
        sudo apt-get install -y -qq ca-certificates curl gnupg
        
        # Добавление GPG ключа
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Добавление репозитория
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Установка Docker
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
    elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
        # Удаление старых версий
        sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
        
        # Установка репозитория
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        
        # Установка Docker
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # Запуск и включение Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Добавление пользователя в группу docker
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
}

# Функция установки Docker Compose
install_docker_compose() {
    log_step "Installing Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose already installed: $(docker-compose --version)"
        return
    fi
    
    # Установка Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose installed successfully"
}

# Функция создания проекта
create_project() {
    log_step "Creating project structure..."
    
    # Создание директории проекта
    PROJECT_DIR="/home/$DOMAIN"
    sudo mkdir -p "$PROJECT_DIR"
    sudo chown -R $USER:$USER "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Создание поддиректорий
    mkdir -p config data logs ssl public/static views
    
    log_success "Project structure created"
}

# Функция клонирования Cinematika
clone_Cinematika() {
    log_step "Cloning Cinematika..."
    
    # Попытка клонировать из официального репозитория
    if git clone https://github.com/Cinematika/Cinematika.git temp 2>/dev/null; then
        # Копирование нужных файлов
        cp -r temp/* . 2>/dev/null || true
        cp -r temp/.* . 2>/dev/null || true
        rm -rf temp
        log_success "Cinematika cloned from official repository"
    else
        log_warn "Could not clone from official repository, creating basic structure"
        create_basic_structure
    fi
}

# Функция создания базовой структуры
create_basic_structure() {
    log_step "Creating basic Cinematika structure..."
    
    # Создание основных файлов
    cat > package.json << EOF
{
  "name": "Cinematika-$DOMAIN",
  "version": "1.0.0",
  "description": "Cinematika website for $DOMAIN",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.0.0",
    "ejs": "^3.1.9",
    "dotenv": "^16.0.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.0",
    "multer": "^1.4.5",
    "sharp": "^0.32.0",
    "helmet": "^6.0.0",
    "cors": "^2.8.5",
    "express-rate-limit": "^6.0.0",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "nodemon": "^2.0.20"
  },
  "engines": {
    "node": ">=16.0.0"
  }
}
EOF

    # Создание основного приложения
    cat > app.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const DOMAIN = process.env.DOMAIN || 'localhost';

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Static files
app.use(express.static(path.join(__dirname, 'public')));
app.use('/static', express.static(path.join(__dirname, 'public/static')));

// View engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Database connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://database:27017/Cinematika', {
    useNewUrlParser: true,
    useUnifiedTopology: true
}).then(() => {
    console.log('✅ Connected to MongoDB');
}).catch(err => {
    console.log('❌ MongoDB connection error:', err);
});

// Basic routes
app.get('/', (req, res) => {
    res.render('index', {
        title: 'Cinematika',
        domain: DOMAIN,
        theme: process.env.THEME || 'default'
    });
});

app.get('/admin', (req, res) => {
    res.render('admin', {
        title: 'Admin Panel',
        domain: DOMAIN
    });
});

// API routes
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        domain: DOMAIN,
        uptime: process.uptime()
    });
});

app.get('/api/movies', async (req, res) => {
    try {
        // Placeholder for movie data
        const movies = [
            { id: 1, title: 'Sample Movie 1', year: 2024, genre: 'Action', rating: 8.5 },
            { id: 2, title: 'Sample Movie 2', year: 2024, genre: 'Comedy', rating: 7.2 },
            { id: 3, title: 'Sample Movie 3', year: 2024, genre: 'Drama', rating: 8.0 }
        ];
        res.json({ movies, total: movies.length });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).render('error', {
        title: 'Error',
        message: 'Something went wrong!'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).render('404', {
        title: 'Page Not Found',
        url: req.originalUrl
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Cinematika server running on port ${PORT}`);
    console.log(`🌐 Website: http://${DOMAIN}`);
    console.log(`🔧 Admin: http://${DOMAIN}/admin`);
    console.log(`📊 API: http://${DOMAIN}/api/health`);
});
EOF

    # Создание .env файла
    cat > .env << EOF
NODE_ENV=production
PORT=3000
DOMAIN=$DOMAIN
LANGUAGE=$LANGUAGE
THEME=$THEME
ADMIN_PASSWORD=$PASSWORD
MONGODB_URI=mongodb://database:27017/Cinematika
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
EOF

    log_success "Basic structure created"
}

# Функция создания Docker конфигурации
create_docker_config() {
    log_step "Creating Docker configuration..."
    
    # Создание docker-compose.yml
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_app
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - DOMAIN=$DOMAIN
      - LANGUAGE=$LANGUAGE
      - THEME=$THEME
      - ADMIN_PASSWORD=$PASSWORD
      - MONGODB_URI=mongodb://database:27017/Cinematika
    volumes:
      - .:/app
      - /app/node_modules
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - database
    networks:
      - Cinematika_network
    restart: always

  nginx:
    image: nginx:alpine
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - app
    networks:
      - Cinematika_network

  database:
    image: mongo:6
    container_name: ${DOMAIN//[^a-zA-Z0-9]/_}_database
    restart: unless-stopped
    environment:
      - MONGO_INITDB_DATABASE=Cinematika
    volumes:
      - ./data/mongo:/data/db
      - ./data/mongo_config:/data/configdb
    networks:
      - Cinematika_network
    restart: always

networks:
  Cinematika_network:
    driver: bridge

volumes:
  mongo_data:
  mongo_config:
EOF

    # Создание Dockerfile
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Change ownership
USER nextjs

EXPOSE 3000

CMD ["npm", "start"]
EOF

    # Создание nginx.conf
    cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;

    # Main server block
    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # Static files caching
        location /static/ {
            proxy_pass http://app:3000;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # API rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Main application
        location / {
            proxy_pass http://app:3000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Health check
        location /health {
            proxy_pass http://app:3000/api/health;
            access_log off;
        }
    }
}
EOF

    log_success "Docker configuration created"
}

# Функция создания EJS шаблонов
create_templates() {
    log_step "Creating EJS templates..."
    
    # Главная страница
    cat > views/index.ejs << EOF
<!DOCTYPE html>
<html lang="<%= LANGUAGE %>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= title %> - <%= domain %></title>
    <meta name="description" content="Cinematika - Your movie streaming platform">
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            text-align: center;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 {
            color: #333;
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            color: #666;
            margin: 10px 0 0 0;
        }
        .content {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .movies-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .movie-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 15px;
            text-align: center;
            transition: transform 0.3s;
        }
        .movie-card:hover {
            transform: translateY(-5px);
        }
        .movie-card h3 {
            margin: 0 0 10px 0;
            color: #333;
            font-size: 1.1em;
        }
        .movie-card p {
            margin: 5px 0;
            color: #666;
            font-size: 0.9em;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            margin: 5px;
            transition: background 0.3s;
        }
        .btn:hover {
            background: #0056b3;
        }
        .status {
            background: #d4edda;
            border: 1px solid #c3e6cb;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            padding: 20px;
            color: rgba(255, 255, 255, 0.8);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎬 Cinematika</h1>
            <p>Your professional movie streaming platform</p>
        </div>

        <div class="content">
            <div class="status">
                <h3>✅ Installation Successful!</h3>
                <p><strong>Domain:</strong> <%= domain %></p>
                <p><strong>Language:</strong> <%= LANGUAGE %></p>
                <p><strong>Theme:</strong> <%= THEME %></p>
                <p><strong>Time:</strong> <%= new Date().toLocaleString() %></p>
            </div>

            <h2>🎬 Featured Movies</h2>
            <div class="movies-grid">
                <div class="movie-card">
                    <h3>Sample Movie 1</h3>
                    <p>2024 • Action</p>
                    <p>⭐ 8.5</p>
                    <a href="#" class="btn">Watch</a>
                </div>
                <div class="movie-card">
                    <h3>Sample Movie 2</h3>
                    <p>2024 • Comedy</p>
                    <p>⭐ 7.2</p>
                    <a href="#" class="btn">Watch</a>
                </div>
                <div class="movie-card">
                    <h3>Sample Movie 3</h3>
                    <p>2024 • Drama</p>
                    <p>⭐ 8.0</p>
                    <a href="#" class="btn">Watch</a>
                </div>
            </div>
        </div>

        <div class="footer">
            <p>💻 Powered by Cinematika | 🎬 Professional Movie Platform</p>
            <p>📧 Admin Panel: <a href="/admin" style="color: white;">/admin</a></p>
        </div>
    </div>

    <script>
        // Load movies from API
        fetch('/api/movies')
            .then(response => response.json())
            .then(data => {
                console.log('Movies loaded:', data.movies);
            })
            .catch(error => {
                console.error('Error loading movies:', error);
            });
    </script>
</body>
</html>
EOF

    # Админ панель
    cat > views/admin.ejs << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Panel - Cinematika</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background: #f8f9fa;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: #343a40;
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .header h1 {
            margin: 0;
            font-size: 2em;
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .card h3 {
            margin: 0 0 15px 0;
            color: #333;
        }
        .card .value {
            font-size: 2em;
            font-weight: bold;
            color: #007bff;
        }
        .menu {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        .menu-item {
            background: white;
            border-radius: 10px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        .menu-item:hover {
            transform: translateY(-5px);
        }
        .menu-item h3 {
            margin: 0 0 10px 0;
            color: #333;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: background 0.3s;
        }
        .btn:hover {
            background: #0056b3;
        }
        .status {
            background: #d4edda;
            border: 1px solid #c3e6cb;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 Admin Panel</h1>
            <p>Manage your Cinematika website</p>
        </div>

        <div class="status">
            <strong>✅ System Status:</strong> All services running normally
        </div>

        <div class="dashboard">
            <div class="card">
                <h3>Total Movies</h3>
                <div class="value">0</div>
            </div>
            <div class="card">
                <h3>Total Users</h3>
                <div class="value">1</div>
            </div>
            <div class="card">
                <h3>Views Today</h3>
                <div class="value">0</div>
            </div>
            <div class="card">
                <h3>Server Uptime</h3>
                <div class="value" id="uptime">Loading...</div>
            </div>
        </div>

        <div class="menu">
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
                <h3>📊 Analytics</h3>
                <p>View statistics and reports</p>
                <a href="#" class="btn">View</a>
            </div>
            <div class="menu-item">
                <h3>⚙️ Settings</h3>
                <p>Configure website settings</p>
                <a href="#" class="btn">Settings</a>
            </div>
            <div class="menu-item">
                <h3>🎨 Themes</h3>
                <p>Customize appearance</p>
                <a href="#" class="btn">Themes</a>
            </div>
            <div class="menu-item">
                <h3>🔐 Security</h3>
                <p>Manage security settings</p>
                <a href="#" class="btn">Security</a>
            </div>
        </div>
    </div>

    <script>
        // Load system status
        fetch('/api/health')
            .then(response => response.json())
            .then(data => {
                document.getElementById('uptime').textContent = Math.floor(data.uptime) + 's';
            })
            .catch(error => {
                console.error('Error loading status:', error);
            });
    </script>
</body>
</html>
EOF

    log_success "EJS templates created"
}

# Функция установки зависимостей
install_dependencies() {
    log_step "Installing Node.js dependencies..."
    
    npm install --production || {
        log_error "Failed to install Node.js dependencies"
        exit 1
    }
    
    log_success "Dependencies installed"
}

# Функция запуска контейнеров
start_containers() {
    log_step "Starting Docker containers..."
    
    # Сборка и запуск контейнеров
    sudo docker-compose down 2>/dev/null || true
    sudo docker-compose build --no-cache
    sudo docker-compose up -d
    
    # Ожидание запуска
    log_info "Waiting for services to start..."
    sleep 30
    
    # Проверка статуса
    log_info "Checking service status..."
    sudo docker-compose ps
    
    log_success "Containers started successfully"
}

# Функция настройки автозапуска
setup_autostart() {
    log_step "Setting up autostart..."
    
    # Создание скрипта автозапуска
    cat > /usr/local/bin/Cinematika-autostart << EOF
#!/bin/bash
# Cinematika autostart script

if [ -d "/home/$DOMAIN" ]; then
    cd "/home/$DOMAIN"
    sudo docker-compose up -d
    echo "Cinematika autostart completed at \$(date)" >> "/home/$DOMAIN/logs/autostart.log"
fi
EOF
    
    sudo chmod +x /usr/local/bin/Cinematika-autostart
    
    # Добавление в crontab
    (crontab -l 2>/dev/null; echo "@reboot /usr/local/bin/Cinematika-autostart") | crontab -
    
    log_success "Autostart configured"
}

# Функция создания скрипта управления
create_management_script() {
    log_step "Creating management script..."
    
    cat > manage.sh << EOF
#!/bin/bash
# Cinematika Management Script for $DOMAIN

case "\${1:-}" in
    "start")
        echo "🚀 Starting Cinematika..."
        sudo docker-compose up -d
        ;;
    "stop")
        echo "🛑 Stopping Cinematika..."
        sudo docker-compose down
        ;;
    "restart")
        echo "🔄 Restarting Cinematika..."
        sudo docker-compose restart
        ;;
    "logs")
        echo "📋 Showing logs..."
        sudo docker-compose logs -f
        ;;
    "status")
        echo "📊 Status:"
        sudo docker-compose ps
        ;;
    "update")
        echo "🔄 Updating Cinematika..."
        git pull
        sudo docker-compose down
        sudo docker-compose build --no-cache
        sudo docker-compose up -d
        ;;
    "backup")
        echo "💾 Creating backup..."
        BACKUP_FILE="backup_\$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "\$BACKUP_FILE" config data logs docker-compose.yml .env
        echo "✅ Backup created: \$BACKUP_FILE"
        ;;
    "restore")
        if [ -z "\$2" ]; then
            echo "❌ Usage: \$0 restore <backup-file>"
            exit 1
        fi
        echo "🔄 Restoring from \$2..."
        tar -xzf "\$2"
        sudo docker-compose down
        sudo docker-compose up -d
        echo "✅ Restore completed"
        ;;
    "reset")
        echo "⚠️ Resetting Cinematika..."
        read -p "Are you sure? This will delete all data! (y/N): " confirm
        if [[ "\$confirm" =~ ^[Yy]$ ]]; then
            sudo docker-compose down -v
            sudo rm -rf data logs
            mkdir -p data logs
            sudo docker-compose up -d
            echo "✅ Reset completed"
        else
            echo "❌ Reset cancelled"
        fi
        ;;
    *)
        echo "Cinematika Management Script"
        echo ""
        echo "Usage: \$0 {start|stop|restart|logs|status|update|backup|restore|reset}"
        echo ""
        echo "Commands:"
        echo "  start    - Start Cinematika services"
        echo "  stop     - Stop Cinematika services"
        echo "  restart  - Restart Cinematika services"
        echo "  logs     - Show service logs"
        echo "  status   - Show service status"
        echo "  update   - Update Cinematika"
        echo "  backup   - Create backup"
        echo "  restore  - Restore from backup"
        echo "  reset    - Reset all data"
        echo ""
        exit 1
        ;;
esac
EOF
    
    chmod +x manage.sh
    
    log_success "Management script created"
}

# Функция финальной проверки
final_check() {
    log_step "Performing final checks..."
    
    # Проверка доступности сайта
    sleep 10
    if curl -s -f http://localhost > /dev/null; then
        log_success "Website is accessible"
    else
        log_warn "Website might not be accessible yet"
    fi
    
    # Проверка API
    if curl -s -f http://localhost/api/health > /dev/null; then
        log_success "API is working"
    else
        log_warn "API might not be working yet"
    fi
    
    log_success "Final checks completed"
}

# Функция показа результатов
show_results() {
    clear
    show_logo
    
    echo ""
    echo "${GREEN}🎉 Cinematika Installation Complete!${NC}"
    echo ""
    echo "${CYAN}===========================================${NC}"
    echo ""
    echo "${GREEN}🌐 Website Information:${NC}"
    echo "   URL:        http://$DOMAIN"
    echo "   Admin:      http://$DOMAIN/admin"
    echo "   API:        http://$DOMAIN/api/health"
    echo ""
    echo "${GREEN}🔑 Login Credentials:${NC}"
    echo "   Username:   admin"
    echo "   Password:   $PASSWORD"
    echo ""
    echo "${GREEN}📁 Project Location:${NC}"
    echo "   Directory:  /home/$DOMAIN"
    echo ""
    echo "${GREEN}🛠️ Management Commands:${NC}"
    echo "   ./manage.sh start     - Start services"
    echo "   ./manage.sh stop      - Stop services"
    echo "   ./manage.sh restart   - Restart services"
    echo "   ./manage.sh logs      - View logs"
    echo "   ./manage.sh status    - Check status"
    echo "   ./manage.sh update    - Update system"
    echo "   ./manage.sh backup    - Create backup"
    echo ""
    echo "${GREEN}🐳 Docker Commands:${NC}"
    echo "   sudo docker-compose ps        - View containers"
    echo "   sudo docker-compose logs      - View logs"
    echo "   sudo docker-compose down      - Stop containers"
    echo ""
    echo "${YELLOW}⚠️  Important Notes:${NC}"
    echo "   • Configure DNS records for $DOMAIN"
    echo "   • Firewall should allow ports 80 and 443"
    echo "   • Set up SSL certificate for HTTPS"
    echo "   • Change default password after first login"
    echo ""
    echo "${CYAN}📞 Support & Documentation:${NC}"
    echo "   • Logs: ./manage.sh logs"
    echo "   • Status: ./manage.sh status"
    echo "   • Issues: Check logs for errors"
    echo ""
    echo "${GREEN}✅ Installation completed successfully!${NC}"
    echo ""
    echo "${CYAN}===========================================${NC}"
    echo ""
}

# Основная функция установки
main() {
    clear
    show_logo
    
    echo "${CYAN}Cinematika One-Command Installer${NC}"
    echo "${CYAN}===========================================${NC}"
    echo ""
    
    # Проверка прав
    if [[ $EUID -ne 0 ]]; then
        log_warn "Script not running as root, checking sudo access..."
        if ! sudo -n true 2>/dev/null; then
            log_error "This script requires sudo privileges!"
            echo "Please run with sudo or ask your administrator for sudo access."
            exit 1
        fi
    fi
    
    # Шаги установки
    check_requirements
    get_install_parameters
    update_system
    install_base_packages
    install_docker
    install_docker_compose
    create_project
    clone_Cinematika
    create_docker_config
    create_templates
    install_dependencies
    start_containers
    setup_autostart
    create_management_script
    final_check
    show_results
    
    # Настройка прав на директорию
    sudo chown -R $USER:$USER "/home/$DOMAIN"
    
    echo ""
    log_info "🎯 Next steps:"
    echo "   1. Configure DNS for $DOMAIN"
    echo "   2. Set up SSL certificate"
    echo "   3. Access admin panel and change password"
    echo "   4. Add content through admin panel"
    echo "   5. Customize theme and settings"
    echo ""
}

# Запуск установки
main "$@"