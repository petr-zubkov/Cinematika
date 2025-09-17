# 🚀 Установка одной командой

## Самый простой способ развертывания

### Метод 1: Локальный скрипт (рекомендуется)

```bash
./quick-install.sh ваш-домен.com admin 192.168.1.100 https://github.com/ваш-юзер/ваш-репо.git
```

### Метод 2: Прямо из интернета

```bash
curl -sSL https://raw.githubusercontent.com/ваш-юзер/ваш-репо/main/quick-install.sh | bash -s -- ваш-домен.com admin 192.168.1.100 https://github.com/ваш-юзер/ваш-репо.git
```

### Метод 3: Через GitHub Gist

```bash
curl -sSL https://gist.githubusercontent.com/ваш-юзер/ваш-gist-id/raw/quick-install.sh | bash -s -- ваш-домен.com admin 192.168.1.100 https://github.com/ваш-юзер/ваш-репо.git
```

## 📋 Что нужно для установки

Перед запуском убедитесь, что у вас есть:
1. **SSH доступ** к серверу с правами sudo
2. **Доменное имя** (например, example.com)
3. **Git репозиторий** с вашим проектом
4. **IP адрес** вашего сервера

## 🔧 Примеры использования

### Базовый пример
```bash
./quick-install.sh example.com admin 192.168.1.100 https://github.com/myuser/myproject.git
```

### С реальными данными
```bash
./quick-install.sh cinematika.com root 203.0.113.10 https://github.com/cinematika/app.git
```

### Через curl (если скрипт на GitHub)
```bash
curl -sSL https://raw.githubusercontent.com/cinematika/app/main/quick-install.sh | bash -s -- cinematika.com root 203.0.113.10 https://github.com/cinematika/app.git
```

## 🚀 Процесс установки (автоматически)

Скрипт автоматически выполнит следующие шаги:

1. **Подключение к серверу** по SSH
2. **Обновление системы** и установка базовых пакетов
3. **Установка Node.js 20** и npm
4. **Установка PM2** для управления процессами
5. **Установка Nginx** как reverse proxy
6. **Настройка Firewall** (ufw)
7. **Клонирование проекта** из Git репозитория
8. **Установка зависимостей** (npm install)
9. **Настройка базы данных** (Prisma)
10. **Сборка проекта** (npm run build)
11. **Настройка PM2** и запуск приложения
12. **Настройка Nginx** конфигурации
13. **Создание .env файла** с настройками
14. **Запуск всех сервисов**
15. **Предложение установить SSL** сертификат

## ✅ После установки

### Проверка работы
```bash
# Проверить статус приложения
ssh admin@ваш-ip "pm2 status"

# Проверить статус Nginx
ssh admin@ваш-ip "sudo systemctl status nginx"

# Проверить логи
ssh admin@ваш-ip "pm2 logs"
```

### Доступ к сайту
- Без SSL: `http://ваш-домен.com`
- С SSL: `https://ваш-домен.com` (если установили)

## 🛠 Управление после установки

### Подключение к серверу
```bash
ssh admin@ваш-ip
```

### Основные команды
```bash
# Перейти в директорию проекта
cd /var/www/your-project-name

# Проверить статус приложения
pm2 status

# Посмотреть логи приложения
pm2 logs

# Перезапустить приложение
pm2 restart nextjs-app

# Проверить статус Nginx
sudo systemctl status nginx

# Перезапустить Nginx
sudo systemctl restart nginx
```

### Обновление приложения
```bash
cd /var/www/your-project-name
git pull origin main
npm install
npm run build
pm2 restart nextjs-app
```

## 🔍 Если что-то пошло не так

### Проверка логов
```bash
# Логи приложения
ssh admin@ваш-ip "pm2 logs"

# Логи Nginx
ssh admin@ваш-ip "sudo tail -f /var/log/nginx/error.log"

# Системные логи
ssh admin@ваш-ip "sudo journalctl -xe"
```

### Перезапуск сервисов
```bash
# Перезапустить все сервисы
ssh admin@ваш-ip "pm2 restart all && sudo systemctl restart nginx"

# Перезапустить только приложение
ssh admin@ваш-ip "pm2 restart nextjs-app"

# Перезапустить только Nginx
ssh admin@ваш-ip "sudo systemctl restart nginx"
```

### Проверка портов
```bash
# Проверить, какие порты слушаются
ssh admin@ваш-ip "sudo netstat -tulpn | grep :3000"
ssh admin@ваш-ip "sudo netstat -tulpn | grep :80"
ssh admin@ваш-ip "sudo netstat -tulpn | grep :443"
```

## 🎯 Советы по использованию

### 1. Перед первым запуском
- Убедитесь, что ваш Git репозиторий доступен
- Проверьте, что у вас есть права на запись в сервер
- Убедитесь, что домен указывает на IP сервера (DNS)

### 2. Во время установки
- Скрипт может спросить пароль SSH - это нормально
- Процесс занимает 5-15 минут в зависимости от скорости интернета
- Если установка прервалась, можно запустить заново

### 3. После установки
- Настройте DNS записи для домена
- Установите SSL сертификат (если не сделали это автоматически)
- Проверьте работу сайта

## 🚨 Распространенные проблемы

### 1. "Permission denied"
```bash
# Убедитесь, что у пользователя есть права sudo
ssh admin@ваш-ip "sudo -v"
```

### 2. "Port already in use"
```bash
# Проверьте, что порт 3000 свободен
ssh admin@ваш-ip "sudo lsof -i :3000"
```

### 3. "Git repository not found"
```bash
# Проверьте URL репозитория
git ls-remote https://github.com/ваш-юзер/ваш-репо.git
```

### 4. "Nginx configuration error"
```bash
# Проверьте конфигурацию Nginx
ssh admin@ваш-ip "sudo nginx -t"
```

## 📞 Поддержка

Если у вас возникли проблемы:
1. Проверьте логи: `ssh admin@ваш-ip "pm2 logs"`
2. Проверьте статус: `ssh admin@ваш-ip "pm2 status"`
3. Перезапустите: `ssh admin@ваш-ip "pm2 restart nextjs-app"`

---

**Готово! Теперь вы можете развернуть ваше приложение одной командой!** 🎉