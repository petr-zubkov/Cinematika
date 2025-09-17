#!/bin/bash

# Скрипт для быстрого развертывания Next.js приложения на сервере
# Запускать на сервере после SSH подключения

set -e

echo "=== Начало развертывания Next.js приложения ==="

# Конфигурация
PROJECT_NAME="nextjs-app"
DOMAIN="your-domain.com"  # Измените на ваш домен
SERVER_PORT="3000"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен с правами root"
   exit 1
fi

# Шаг 1: Обновление системы
log_info "Обновление системы..."
apt update && apt upgrade -y

# Шаг 2: Установка Node.js
log_info "Установка Node.js..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source /root/.bashrc
nvm install 20
nvm use 20
nvm alias default 20

# Проверка установки Node.js
NODE_VERSION=$(node -v)
log_info "Установлен Node.js $NODE_VERSION"

# Шаг 3: Установка PM2
log_info "Установка PM2..."
npm install -g pm2

# Шаг 4: Установка Nginx
log_info "Установка Nginx..."
apt install nginx -y

# Шаг 5: Создание директории проекта
log_info "Создание директории проекта..."
mkdir -p /var/www/$PROJECT_NAME
cd /var/www/$PROJECT_NAME

# Шаг 6: Копирование файлов проекта (предполагается, что файлы уже скопированы)
if [ ! -f "package.json" ]; then
    log_error "package.json не найден. Убедитесь, что файлы проекта скопированы в /var/www/$PROJECT_NAME"
    exit 1
fi

# Шаг 7: Установка зависимостей
log_info "Установка зависимостей..."
npm install

# Шаг 8: Сборка проекта
log_info "Сборка проекта..."
npm run build

# Шаг 9: Настройка базы данных
log_info "Настройка базы данных..."
npm run db:push
npm run db:generate

# Шаг 10: Создание ecosystem.config.js
log_info "Создание PM2 конфигурации..."
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '$PROJECT_NAME',
    script: 'server.ts',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: $SERVER_PORT
    },
    interpreter: 'tsx',
    interpreter_args: '',
    watch: false,
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024'
  }]
};
EOF

# Шаг 11: Запуск приложения через PM2
log_info "Запуск приложения через PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Шаг 12: Настройка Nginx
log_info "Настройка Nginx..."
cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    location / {
        proxy_pass http://localhost:$SERVER_PORT;
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
        proxy_pass http://localhost:$SERVER_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /_next/static/ {
        alias /var/www/$PROJECT_NAME/.next/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /public/ {
        alias /var/www/$PROJECT_NAME/public/;
        expires 1y;
        add_header Cache-Control "public";
    }
}
EOF

# Активация конфигурации Nginx
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Тестирование и перезагрузка Nginx
nginx -t && systemctl reload nginx

# Шаг 13: Настройка файрвола
log_info "Настройка файрвола..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Шаг 14: Создание скрипта для обновления
log_info "Создание скрипта для обновления..."
cat > update.sh << 'EOF'
#!/bin/bash
echo "Обновление проекта..."
git pull origin main
npm install
npm run build
npm run db:push
pm2 restart nextjs-app
echo "Обновление завершено!"
EOF

chmod +x update.sh

# Шаг 15: Вывод информации
log_info "Развертывание завершено!"
echo ""
echo "=== Информация о развертывании ==="
echo "Проект: $PROJECT_NAME"
echo "Домен: $DOMAIN"
echo "Порт: $SERVER_PORT"
echo ""
echo "Статус PM2:"
pm2 status
echo ""
echo "Для просмотра логов: pm2 logs $PROJECT_NAME"
echo "Для перезапуска: pm2 restart $PROJECT_NAME"
echo "Для обновления: ./update.sh"
echo ""
log_warn "Не забудьте:"
echo "1. Настроить DNS для домена $DOMAIN"
echo "2. Настроить SSL сертификат: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
echo "3. Изменить DOMAIN в скрипте на ваш реальный домен"
echo ""

echo "=== Развертывание успешно завершено! ==="