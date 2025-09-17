# 🚀 Шпаргалка по развертыванию

## Быстрое развертывание

### Автоматическое (рекомендуется)
```bash
./deploy.sh your-domain.com admin 192.168.1.100
```

### Ручное
```bash
# Подключение к серверу
ssh username@server-ip

# Установка Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20

# Установка PM2 и Nginx
npm install -g pm2
sudo apt install nginx -y

# Клонирование проекта
cd /var/www
git clone your-repo-url
cd your-project-name

# Установка зависимостей и сборка
npm install
npx prisma generate
npx prisma db push
npm run build

# Запуск с PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

## Управление приложением

### PM2 команды
```bash
pm2 status          # Статус
pm2 logs           # Логи
pm2 restart app    # Перезапуск
pm2 stop app       # Остановка
pm2 monit          # Мониторинг
```

### Nginx команды
```bash
sudo systemctl status nginx    # Статус
sudo systemctl restart nginx  # Перезапуск
sudo nginx -t                 # Проверка конфига
sudo tail -f /var/log/nginx/error.log  # Логи ошибок
```

### Обновление приложения
```bash
cd /var/www/your-project-name
git pull origin main
npm install
npm run build
pm2 restart your-app-name
```

## Docker развертывание

### Сборка и запуск
```bash
docker-compose up -d --build
```

### Просмотр логов
```bash
docker-compose logs -f app
docker-compose logs -f nginx
```

### Остановка
```bash
docker-compose down
```

## Полезные команды

### Проверка портов
```bash
sudo lsof -i :3000
sudo netstat -tulpn | grep :3000
```

### Проверка прав доступа
```bash
sudo chown -R $USER:$USER /var/www/your-project-name
sudo chmod -R 755 /var/www/your-project-name
```

### Проверка дискового пространства
```bash
df -h
du -sh /var/www/your-project-name
```

### Проверка использования памяти
```bash
free -h
htop
```

## SSL с Let's Encrypt

### Установка Certbot
```bash
sudo apt install certbot python3-certbot-nginx -y
```

### Получение сертификата
```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

### Автоматическое обновление
```bash
sudo crontab -e
# Добавить: 0 12 * * * /usr/bin/certbot renew --quiet
```

## Резервное копирование

### Бэкап базы данных
```bash
cp /var/www/your-project-name/prisma/dev.db /backup/db_$(date +%Y%m%d).db
```

### Бэкап файлов
```bash
tar -czf /backup/files_$(date +%Y%m%d).tar.gz /var/www/your-project-name
```

### Восстановление
```bash
tar -xzf /backup/files_YYYYMMDD.tar.gz -C /var/www/
cp /backup/db_YYYYMMDD.db /var/www/your-project-name/prisma/dev.db
```

## Безопасность

### Обновление системы
```bash
sudo apt update && sudo apt upgrade -y
```

### Настройка Firewall
```bash
sudo ufw status
sudo ufw allow 'Nginx Full'
sudo ufw allow ssh
sudo ufw enable
```

### Проверка безопасности
```bash
sudo fail2ban-client status
sudo systemctl status fail2ban
```

## Мониторинг

### Системные ресурсы
```bash
htop                    # Процессы и память
df -h                   # Дисковое пространство
free -h                 # Память
iostat                  # Дисковая активность
```

### Логи приложения
```bash
pm2 logs               # Логи PM2
tail -f logs/out.log   # Логи приложения
tail -f logs/err.log   # Логи ошибок
```

### Логи Nginx
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Экстренные команды

### Перезапуск всего стека
```bash
pm2 restart all
sudo systemctl restart nginx
```

### Очистка логов
```bash
pm2 flush
sudo logrotate -f /etc/logrotate.conf
```

### Проверка зависимостей
```bash
npm audit
npm outdated
```

### Восстановление после сбоя
```bash
# 1. Проверить логи
pm2 logs
sudo tail -f /var/log/nginx/error.log

# 2. Перезапустить сервисы
pm2 restart your-app-name
sudo systemctl restart nginx

# 3. Проверить статус
pm2 status
sudo systemctl status nginx

# 4. Если проблема persists, пересобрать приложение
npm run build
pm2 restart your-app-name
```

## Полезные ссылки

- [PM2 Documentation](https://pm2.keymetrics.io/docs/usage/quick-start/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Docker Documentation](https://docs.docker.com/)

---

**Важно:** Всегда проверяйте конфигурационные файлы перед перезапуском сервисов!