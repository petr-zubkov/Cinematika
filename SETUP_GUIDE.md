# Полное руководство по установке сайта на сервер

## 🚀 Быстрый старт

Это руководство поможет вам развернуть Next.js 15 приложение на сервере по SSH.

### 📋 Что вам понадобится:
- SSH доступ к серверу (Ubuntu 20.04/22.04)
- Доменное имя (опционально)
- 15-30 минут времени

---

## 📁 Шаг 1: Подготовка файлов к загрузке

### 1.1 Проверьте состав проекта
Убедитесь, что у вас есть все необходимые файлы:
```
├── package.json
├── server.ts
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── prisma/
│   └── schema.prisma
├── src/
│   ├── app/
│   ├── components/
│   └── lib/
└── public/
```

### 1.2 Исключите ненужные файлы
Создайте файл `.gitignore` (если его нет):
```
node_modules
.next
.env.local
.env.development.local
.env.test.local
.env.production.local
*.log
.DS_Store
coverage
.nyc_output
```

---

## 📤 Шаг 2: Загрузка файлов на сервер

### Выберите один из методов:

#### Метод A: Использование RSYNC (рекомендуется)
```bash
# На локальной машине
rsync -avz --progress \
  --exclude='node_modules' \
  --exclude='.next' \
  --exclude='.git' \
  --exclude='*.log' \
  ./ user@your-server-ip:/var/www/nextjs-app/
```

#### Метод B: Использование SCP
```bash
# На локальной машине
scp -r ./ user@your-server-ip:/var/www/nextjs-app/
```

#### Метод C: Использование Git (для разработки)
```bash
# На локальной машине
git remote add production user@your-server-ip:/var/git/nextjs-app.git
git push production main
```

---

## 🔧 Шаг 3: Настройка сервера (автоматически)

### 3.1 Запустите автоматический скрипт
```bash
# Подключитесь к серверу
ssh user@your-server-ip

# Сделайте скрипт исполняемым и запустите
chmod +x QUICK_DEPLOY.sh
sudo ./QUICK_DEPLOY.sh
```

### 3.2 Вручную (если автоматический не сработал)
```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20

# Установка PM2 и Nginx
npm install -g pm2
sudo apt install nginx -y

# Переход в директорию проекта
cd /var/www/nextjs-app

# Установка зависимостей и сборка
npm install
npm run build
npm run db:push
npm run db:generate

# Запуск приложения
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

---

## 🌐 Шаг 4: Настройка домена и SSL

### 4.1 Настройте DNS
Укажите в настройках DNS вашего домена:
```
A запись: your-server-ip
```

### 4.2 Установите SSL сертификат
```bash
# Установка Certbot
sudo apt install certbot python3-certbot-nginx -y

# Получение сертификата
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

### 4.3 Настройте автоматическое обновление SSL
```bash
# Добавьте в cron
sudo crontab -e
```
Добавьте строку:
```
0 12 * * * /usr/bin/certbot renew --quiet
```

---

## 🧪 Шаг 5: Проверка и тестирование

### 5.1 Проверьте статус приложений
```bash
# Статус PM2
pm2 status

# Статус Nginx
sudo systemctl status nginx

# Просмотр логов
pm2 logs nextjs-app
```

### 5.2 Проверьте работу сайта
Откройте в браузере:
- `http://your-server-ip` - должен работать
- `https://your-domain.com` - должен работать с SSL

### 5.3 Проверьте все функции
- [ ] Главная страница загружается
- [ ] Socket.IO работает (если используется)
- [ ] База данных подключена
- [ ] Все страницы работают
- [ ] Мобильная версия работает

---

## 🔄 Шаг 6: Обновление сайта

### 6.1 Быстрое обновление
```bash
# На локальной машине
rsync -avz ./ user@your-server-ip:/var/www/nextjs-app/

# На сервере
ssh user@your-server-ip
cd /var/www/nextjs-app
./update.sh
```

### 6.2 Полное обновление
```bash
# На сервере
cd /var/www/nextjs-app
git pull origin main
npm install
npm run build
npm run db:push
pm2 restart nextjs-app
```

---

## 🛠️ Шаг 7: Управление и обслуживание

### 7.1 Полезные команды
```bash
# Просмотр логов в реальном времени
pm2 logs nextjs-app

# Перезапуск приложения
pm2 restart nextjs-app

# Перезагрузка Nginx
sudo systemctl reload nginx

# Проверка дискового пространства
df -h

# Проверка использования памяти
free -h
```

### 7.2 Резервное копирование
```bash
# Создайте бэкап
./backup.sh

# Восстановление из бэкапа
# (инструкции в DEPLOYMENT.md)
```

---

## 🚨 Шаг 8: Решение проблем

### Частые проблемы и решения:

#### Проблема: Сайт не загружается
```bash
# Проверьте статус PM2
pm2 status

# Проверьте логи
pm2 logs nextjs-app

# Проверьте Nginx
sudo nginx -t
sudo systemctl status nginx
```

#### Проблема: Ошибка 502 Bad Gateway
```bash
# Проверьте, запущено ли приложение
pm2 status

# Перезапустите приложение
pm2 restart nextjs-app

# Проверьте порт
netstat -tlnp | grep :3000
```

#### Проблема: Ошибка прав доступа
```bash
# Исправьте права
sudo chown -R $USER:$USER /var/www/nextjs-app
sudo chmod -R 755 /var/www/nextjs-app
```

#### Проблема: База данных не работает
```bash
# Пересоздайте базу данных
npm run db:push
npm run db:generate
```

---

## 📚 Дополнительные ресурсы

- [Полная инструкция по развертыванию](./DEPLOYMENT.md)
- [Инструкция по загрузке файлов](./UPLOAD_INSTRUCTIONS.md)
- [Официальная документация Next.js](https://nextjs.org/docs)
- [Документация PM2](https://pm2.keymetrics.io/docs/usage/quick-start/)
- [Документация Nginx](https://nginx.org/en/docs/)

---

## 🎉 Готово!

Поздравляем! Ваш Next.js сайт теперь развернут на сервере. Если у вас возникнут вопросы или проблемы, обратитесь к разделу решения проблем или к полной инструкции по развертыванию.

### Что дальше?
1. Настройте мониторинг (опционально)
2. Настройте регулярное резервное копирование
3. Добавьте свой контент
4. Расскажите о вашем сайте! 🎉

---

**Поддержка:** Если у вас возникнут проблемы, проверьте логи (`pm2 logs`) и обратитесь к документации.