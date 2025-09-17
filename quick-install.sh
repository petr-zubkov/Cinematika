#!/bin/bash

# Универсальный скрипт установки одной командой
# Использование: curl -sSL https://raw.githubusercontent.com/your-username/your-repo/main/quick-install.sh | bash -s -- [домен] [ssh-пользователь] [ip-сервера] [git-репозиторий]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Проверка параметров
if [ $# -lt 3 ]; then
    log_error "Недостаточно параметров"
    echo "Использование: $0 [домен] [ssh-пользователь] [ip-сервера] [git-репозиторий]"
    echo "Пример: $0 example.com admin 192.168.1.100 https://github.com/user/repo.git"
    exit 1
fi

DOMAIN="$1"
SSH_USER="$2"
SERVER_IP="$3"
GIT_REPO="$4"

# Если репозиторий не указан, спрашиваем
if [ -z "$GIT_REPO" ]; then
    echo -e "${YELLOW}Введите URL вашего Git репозитория:${NC}"
    read -r GIT_REPO
fi

# Проверка формата домена
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    log_error "Неверный формат домена: $DOMAIN"
    exit 1
fi

# Проверка формата IP
if [[ ! "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_error "Неверный формат IP адреса: $SERVER_IP"
    exit 1
fi

log_info "Начало установки приложения на сервер $SERVER_IP"
log_info "Домен: $DOMAIN"
log_info "SSH пользователь: $SSH_USER"
log_info "Git репозиторий: $GIT_REPO"

# Создание временной директории
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_step "1. Создание конфигурационных файлов..."

# Создание ecosystem.config.js
cat > "$TEMP_DIR/ecosystem.config.js" << EOF
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
EOF

# Создание nginx конфига
cat > "$TEMP_DIR/nginx-config" << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /api/socketio/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
}
EOF

# Создание основного скрипта установки
cat > "$TEMP_DIR/install.sh" << 'EOF'
#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Функция проверки команды
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Команда $1 не найдена"
        return 1
    fi
}

# Функция установки пакета
install_package() {
    if ! dpkg -l | grep -q "$1"; then
        log_info "Установка $1..."
        apt-get install -y "$1"
    else
        log_info "$1 уже установлен"
    fi
}

log_step "1. Обновление системы..."
apt-get update
apt-get upgrade -y

log_step "2. Установка базовых пакетов..."
install_package curl
install_package wget
install_package git
install_package build-essential
install_package ufw

log_step "3. Установка Node.js..."
if ! command -v node &> /dev/null || [[ $(node -v | cut -d'.' -f1 | cut -d'v' -f2) -lt 20 ]]; then
    log_info "Установка Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    log_info "Node.js уже установлен: $(node -v)"
fi

log_step "4. Установка PM2..."
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
else
    log_info "PM2 уже установлен"
fi

log_step "5. Установка Nginx..."
install_package nginx

log_step "6. Настройка Firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

log_step "7. Создание директории проекта..."
mkdir -p /var/www/your-project-name
cd /var/www

log_step "8. Клонирование проекта..."
cd /var/www/your-project-name

# Получение URL репозитория из параметров
GIT_REPO="$1"
if [ -z "$GIT_REPO" ]; then
    log_error "Git репозиторий не указан"
    exit 1
fi

# Клонирование проекта
if [ -d ".git" ]; then
    log_info "Репозиторий уже существует, выполняем git pull..."
    git pull origin main || git pull origin master
else
    log_info "Клонирование репозитория: $GIT_REPO"
    git clone "$GIT_REPO" . || {
        log_error "Не удалось клонировать репозиторий"
        log_info "Пожалуйста, проверьте URL репозитория и права доступа"
        exit 1
    }
fi

log_step "9. Установка прав доступа..."
chown -R $USER:$USER /var/www/your-project-name
chmod -R 755 /var/www/your-project-name

log_step "10. Установка зависимостей..."
npm install

log_step "11. Настройка базы данных..."
if [ -f "prisma/schema.prisma" ]; then
    npx prisma generate
    npx prisma db push
else
    log_warn "Файл prisma/schema.prisma не найден, пропускаем настройку базы данных"
fi

log_step "12. Сборка проекта..."
npm run build

log_step "13. Создание директории для логов..."
mkdir -p logs

log_step "14. Настройка PM2..."
if [ -f "/tmp/ecosystem.config.js" ]; then
    cp /tmp/ecosystem.config.js ecosystem.config.js
fi

# Проверка, запущено ли уже приложение
if pm2 describe nextjs-app > /dev/null 2>&1; then
    log_info "Приложение уже запущено, перезапускаем..."
    pm2 restart nextjs-app
else
    log_info "Запуск приложения..."
    pm2 start ecosystem.config.js || {
        log_error "Не удалось запустить приложение через PM2"
        log_info "Пробуем запустить напрямую..."
        npm start
    }
fi

pm2 save
pm2 startup || log_warn "Не удалось настроить автозапуск PM2"

log_step "15. Настройка Nginx..."
if [ -f "/tmp/nginx-config" ]; then
    cp /tmp/nginx-config /etc/nginx/sites-available/your-domain
    ln -sf /etc/nginx/sites-available/your-domain /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Проверка конфигурации Nginx
    if nginx -t; then
        systemctl restart nginx
        log_info "Nginx успешно перезапущен"
    else
        log_error "Ошибка в конфигурации Nginx"
        nginx -t
    fi
fi

log_step "16. Создание .env файла..."
if [ ! -f ".env" ]; then
    cat > .env << EOF
NODE_ENV=production
DATABASE_URL="file:./dev.db"
NEXTAUTH_SECRET=$(openssl rand -base64 32)
NEXTAUTH_URL=http://localhost:3000
EOF
    log_info "Файл .env создан"
else
    log_info "Файл .env уже существует"
fi

log_step "17. Проверка статуса сервисов..."
echo "=== PM2 Status ==="
pm2 status || echo "PM2 не доступен"

echo "=== Nginx Status ==="
systemctl status nginx --no-pager || echo "Nginx не доступен"

echo "=== Port 3000 ==="
netstat -tulpn | grep :3000 || echo "Порт 3000 не доступен"

log_info "Установка завершена!"
log_warn "Важно: не забудьте настроить DNS записи для домена"
log_info "Проверьте работу сайта: http://$DOMAIN"
log_info "Полезные команды:"
echo "  pm2 status           - Проверить статус приложения"
echo "  pm2 logs            - Просмотреть логи"
echo "  sudo systemctl status nginx  - Проверить статус Nginx"
EOF

# Копирование файлов на сервер
log_step "2. Копирование конфигурационных файлов на сервер..."
scp "$TEMP_DIR/ecosystem.config.js" "$SSH_USER@$SERVER_IP:/tmp/" || {
    log_error "Не удалось скопировать ecosystem.config.js"
    exit 1
}

scp "$TEMP_DIR/nginx-config" "$SSH_USER@$SERVER_IP:/tmp/" || {
    log_error "Не удалось скопировать nginx-config"
    exit 1
}

scp "$TEMP_DIR/install.sh" "$SSH_USER@$SERVER_IP:/tmp/" || {
    log_error "Не удалось скопировать install.sh"
    exit 1
}

# Выполнение скрипта установки на сервере
log_step "3. Выполнение установки на сервере..."
ssh "$SSH_USER@$SERVER_IP" "chmod +x /tmp/install.sh && sudo /tmp/install.sh '$GIT_REPO'"

log_step "4. Проверка установки..."
echo "=== Проверка статуса приложения ==="
ssh "$SSH_USER@$SERVER_IP" "pm2 status" || echo "PM2 не доступен"

echo "=== Проверка Nginx ==="
ssh "$SSH_USER@$SERVER_IP" "sudo systemctl status nginx --no-pager" || echo "Nginx не доступен"

log_info "=== Установка завершена! ==="
echo ""
log_info "Ваш сайт должен быть доступен по адресу: http://$DOMAIN"
log_warn "Не забудьте:"
echo "  1. Настроить DNS записи для домена $DOMAIN"
echo "  2. (Опционально) Установить SSL: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
echo "  3. Проверить работу сайта"
echo ""
log_info "Полезные команды:"
echo "  ssh $SSH_USER@$SERVER_IP 'pm2 status'     - Проверить статус приложения"
echo "  ssh $SSH_USER@$SERVER_IP 'pm2 logs'      - Просмотреть логи"
echo "  ssh $SSH_USER@$SERVER_IP 'sudo systemctl status nginx'  - Проверить Nginx"
echo ""
log_info "Для управления сервером:"
echo "  ssh $SSH_USER@$SERVER_IP"
echo "  cd /var/www/your-project-name"

# Предложение установить SSL
echo ""
read -p "Хотите установить SSL сертификат сейчас? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_step "5. Установка SSL сертификата..."
    ssh "$SSH_USER@$SERVER_IP" "sudo apt install certbot python3-certbot-nginx -y && sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
    log_info "SSL сертификат установлен!"
fi

log_info "Готово! Ваш сайт полностью настроен и готов к работе."