#!/bin/bash

# Скрипт автоматического развертывания Next.js приложения на сервере
# Использование: ./deploy.sh [domain] [ssh-user] [server-ip]

set -e

# Параметры
DOMAIN=${1:-"your-domain.com"}
SSH_USER=${2:-"root"}
SERVER_IP=${3:-"your-server-ip"}

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Проверка параметров
if [ "$DOMAIN" = "your-domain.com" ] || [ "$SERVER_IP" = "your-server-ip" ]; then
    log_error "Пожалуйста, укажите домен и IP адрес сервера"
    echo "Использование: ./deploy.sh [domain] [ssh-user] [server-ip]"
    echo "Пример: ./deploy.sh example.com admin 192.168.1.100"
    exit 1
fi

log_info "Начало развертывания приложения на сервере $SERVER_IP"
log_info "Домен: $DOMAIN"
log_info "SSH пользователь: $SSH_USER"

# Создание временной директории для конфигов
TEMP_DIR=$(mktemp -d)
log_info "Создание временной директории: $TEMP_DIR"

# Создание ecosystem.config.js
cat > $TEMP_DIR/ecosystem.config.js << EOL
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

# Создание nginx конфига
cat > $TEMP_DIR/nginx-config << EOL
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
    
    # Для Socket.IO
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
    
    # Статические файлы
    location /_next/static/ {
        alias /var/www/your-project-name/.next/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Оптимизация для больших файлов
    client_max_body_size 100M;
    
    # Сжатие
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
EOL

# Создание скрипта установки
cat > $TEMP_DIR/install-server.sh << 'EOL'
#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Обновление системы
log_info "Обновление системы..."
apt update && apt upgrade -y

# Установка Node.js
log_info "Установка Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Установка PM2
log_info "Установка PM2..."
npm install -g pm2

# Установка Nginx
log_info "Установка Nginx..."
apt install nginx -y

# Установка Git
log_info "Установка Git..."
apt install git -y

# Установка инструментов для сборки
log_info "Установка инструментов для сборки..."
apt install build-essential -y

# Создание директории для проекта
log_info "Создание директории для проекта..."
mkdir -p /var/www/your-project-name
cd /var/www

# Клонирование проекта (здесь нужно будет вручную склонировать проект)
log_warn "Пожалуйста, склонируйте ваш проект в /var/www/your-project-name"
log_warn "Пример: git clone https://github.com/your-username/your-repo.git your-project-name"
log_warn "После клонирования нажмите Enter для продолжения..."
read

# Установка прав
chown -R $USER:$USER /var/www/your-project-name
chmod -R 755 /var/www/your-project-name

cd /var/www/your-project-name

# Установка зависимостей
log_info "Установка зависимостей..."
npm install

# Генерация Prisma
log_info "Генерация Prisma..."
npx prisma generate

# Пуш базы данных
log_info "Пуш базы данных..."
npx prisma db push

# Сборка проекта
log_info "Сборка проекта..."
npm run build

# Создание директории для логов
mkdir -p logs

# Запуск PM2
log_info "Запуск PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Настройка Nginx
log_info "Настройка Nginx..."
cp /tmp/nginx-config /etc/nginx/sites-available/your-domain
ln -s /etc/nginx/sites-available/your-domain /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Проверка конфигурации Nginx
nginx -t

# Перезапуск Nginx
systemctl restart nginx

# Настройка Firewall
log_info "Настройка Firewall..."
ufw allow 'Nginx Full'
ufw allow ssh
ufw --force enable

# Создание .env файла
log_info "Создание .env файла..."
cat > .env << EOF
NODE_ENV=production
DATABASE_URL="file:./dev.db"
NEXTAUTH_SECRET=$(openssl rand -base64 32)
NEXTAUTH_URL=http://localhost:3000
EOF

log_info "Установка завершена!"
log_info "Проверьте статус: pm2 status"
log_info "Проверьте Nginx: systemctl status nginx"
EOL

# Копирование файлов на сервер
log_info "Копирование конфигурационных файлов на сервер..."
scp $TEMP_DIR/ecosystem.config.js $SSH_USER@$SERVER_IP:/tmp/
scp $TEMP_DIR/nginx-config $SSH_USER@$SERVER_IP:/tmp/
scp $TEMP_DIR/install-server.sh $SSH_USER@$SERVER_IP:/tmp/

# Выполнение скрипта установки на сервере
log_info "Выполнение скрипта установки на сервере..."
ssh $SSH_USER@$SERVER_IP "chmod +x /tmp/install-server.sh && sudo /tmp/install-server.sh"

# Очистка
rm -rf $TEMP_DIR

log_info "Развертывание завершено!"
log_warn "Не забудьте:"
log_warn "1. Засклонировать ваш проект на сервере"
log_warn "2. Настроить DNS записи для домена $DOMAIN"
log_warn "3. (Опционально) Установить SSL сертификат: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
log_warn "4. Проверить работу сайта: http://$DOMAIN"

echo ""
log_info "Полезные команды:"
echo "  pm2 status                    - Проверить статус приложения"
echo "  pm2 logs                     - Просмотреть логи"
echo "  pm2 restart nextjs-app       - Перезапустить приложение"
echo "  sudo systemctl status nginx  - Проверить статус Nginx"
echo "  sudo tail -f /var/log/nginx/error.log  - Логи Nginx"