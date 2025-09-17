# Инструкция по установке сайта на сервер по SSH

## Обзор
Это руководство поможет вам развернуть Next.js 15 приложение с TypeScript, Prisma ORM и Socket.IO на сервере через SSH.

## Предварительные требования

### На стороне сервера
- Ubuntu 20.04/22.04 или другой Linux дистрибутив
- Node.js 20+ (рекомендуется использовать NVM)
- PM2 для управления процессами
- Nginx как обратный прокси
- SQLite (для базы данных Prisma)

### На локальной машине
- SSH доступ к серверу
- Git

## Шаг 1: Подключение к серверу

```bash
ssh username@your-server-ip
```

## Шаг 2: Установка Node.js и NPM

### Установка NVM (рекомендуется)
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
node --version  # должно показать 20.x.x
npm --version   # должно показать соответствующую версию
```

### Или установка Node.js напрямую
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## Шаг 3: Установка PM2

```bash
sudo npm install -g pm2
```

## Шаг 4: Установка Nginx

```bash
sudo apt update
sudo apt install nginx -y
```

## Шаг 5: Клонирование проекта

```bash
cd /var/www
sudo mkdir -p your-project-name
sudo chown $USER:$USER /var/www/your-project-name
git clone https://github.com/your-username/your-repo.git your-project-name
cd your-project-name
```

## Шаг 6: Установка зависимостей

```bash
npm install
```

## Шаг 7: Настройка базы данных

### Инициализация Prisma
```bash
npx prisma generate
npx prisma db push
```

## Шаг 8: Сборка проекта

```bash
npm run build
```

## Шаг 9: Настройка PM2

### Создание ecosystem.config.js
Создайте файл `ecosystem.config.js` в корне проекта:

```javascript
module.exports = {
  apps: [{
    name: 'your-app-name',
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
```

### Создание директории для логов
```bash
mkdir -p logs
```

## Шаг 10: Запуск приложения с PM2

```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

## Шаг 11: Настройка Nginx

### Создание конфигурационного файла
```bash
sudo nano /etc/nginx/sites-available/your-domain
```

Добавьте следующую конфигурацию:

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    
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
    
    # Для Socket.IO
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
```

### Активация конфигурации
```bash
sudo ln -s /etc/nginx/sites-available/your-domain /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Шаг 12: Настройка Firewall

```bash
sudo ufw allow 'Nginx Full'
sudo ufw allow ssh
sudo ufw enable
```

## Шаг 13: (Опционально) Настройка SSL с Let's Encrypt

### Установка Certbot
```bash
sudo apt install certbot python3-certbot-nginx -y
```

### Получение SSL сертификата
```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

### Автоматическое обновление сертификата
```bash
sudo crontab -e
```

Добавьте строку:
```
0 12 * * * /usr/bin/certbot renew --quiet
```

## Шаг 14: Управление приложением

### Полезные команды PM2
```bash
# Просмотр статуса процессов
pm2 status

# Просмотр логов
pm2 logs

# Перезапуск приложения
pm2 restart your-app-name

# Остановка приложения
pm2 stop your-app-name

# Удаление приложения
pm2 delete your-app-name

# Мониторинг
pm2 monit
```

### Обновление приложения
```bash
cd /var/www/your-project-name
git pull origin main
npm install
npm run build
pm2 restart your-app-name
```

## Шаг 15: Настройка переменных окружения

Создайте файл `.env` в корне проекта:

```bash
nano .env
```

Добавьте необходимые переменные:
```
NODE_ENV=production
DATABASE_URL="file:./dev.db"
NEXTAUTH_SECRET=your-secret-key
NEXTAUTH_URL=https://your-domain.com
```

## Шаг 16: Резервное копирование

### Скрипт резервного копирования
Создайте файл `backup.sh`:

```bash
#!/bin/bash

BACKUP_DIR="/var/backups/your-app"
APP_DIR="/var/www/your-project-name"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Бэкап базы данных
cp $APP_DIR/prisma/dev.db $BACKUP_DIR/db_$DATE.db

# Бэкап файлов
tar -czf $BACKUP_DIR/files_$DATE.tar.gz -C $APP_DIR .

# Удаление старых бэкапов (старше 30 дней)
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: $DATE"
```

Сделайте скрипт исполняемым:
```bash
chmod +x backup.sh
```

Добавьте в cron для автоматического бэкапа:
```bash
crontab -e
```

Добавьте строку для ежедневного бэкапа в 2:00:
```
0 2 * * * /var/www/your-project-name/backup.sh
```

## Решение распространенных проблем

### 1. Ошибка "Port already in use"
```bash
sudo lsof -i :3000
sudo kill -9 <PID>
```

### 2. Проблемы с правами доступа
```bash
sudo chown -R $USER:$USER /var/www/your-project-name
sudo chmod -R 755 /var/www/your-project-name
```

### 3. Ошибки Nginx
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### 4. Ошибки PM2
```bash
pm2 logs
pm2 describe your-app-name
```

### 5. Проблемы с базой данных
```bash
npx prisma db push
npx prisma generate
```

## Мониторинг

### Установка мониторинга
```bash
npm install -g pm2-web
pm2-web
```

### Системный мониторинг
```bash
htop
df -h
free -h
```

## Безопасность

### 1. Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Настройка SSH
```bash
sudo nano /etc/ssh/sshd_config
```

Измените следующие параметры:
```
PermitRootLogin no
PasswordAuthentication no
Port 2222  # измените стандартный порт
```

Перезапустите SSH:
```bash
sudo systemctl restart sshd
```

### 3. Настройка fail2ban
```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Готово!

Ваш сайт теперь должен быть доступен по адресу:
- http://your-domain.com (без SSL)
- https://your-domain.com (с SSL)

Для проверки статуса используйте:
```bash
pm2 status
sudo systemctl status nginx
```

Если у вас возникли проблемы, проверьте логи:
```bash
pm2 logs
sudo tail -f /var/log/nginx/error.log
```