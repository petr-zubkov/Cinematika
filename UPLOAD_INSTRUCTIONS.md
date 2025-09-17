# Инструкция по загрузке файлов на сервер

## Метод 1: Использование SCP (рекомендуется)

### 1.1 Подготовка
Убедитесь, что у вас есть SSH доступ к серверу:
```bash
ssh user@your-server-ip
```

### 1.2 Загрузка файлов с локальной машины
```bash
# Из корневой директории вашего проекта
scp -r ./ user@your-server-ip:/var/www/nextjs-app/
```

### 1.3 Исключение ненужных файлов
Создайте файл `.scpignore` в корне проекта:
```
node_modules
.next
.git
*.log
.DS_Store
.env.local
.env.development.local
.env.test.local
.env.production.local
```

Затем загрузите с исключением:
```bash
scp -r -X ./.scpignore user@your-server-ip:/var/www/nextjs-app/
```

## Метод 2: Использование RSYNC (быстрее для больших проектов)

### 2.1 Установка RSYNC (если не установлен)
```bash
# На локальной машине (Ubuntu/Debian)
sudo apt install rsync

# На macOS
brew install rsync
```

### 2.2 Загрузка файлов
```bash
rsync -avz --progress \
  --exclude='node_modules' \
  --exclude='.next' \
  --exclude='.git' \
  --exclude='*.log' \
  --exclude='.DS_Store' \
  --exclude='env*.local' \
  ./ user@your-server-ip:/var/www/nextjs-app/
```

### 2.3 Параметры RSYNC
- `-a` - архивный режим (сохраняет права, атрибуты и т.д.)
- `-v` - подробный вывод
- `-z` - сжатие данных при передаче
- `--progress` - показ прогресса загрузки

## Метод 3: Использование Git (рекомендуется для разработки)

### 3.1 Инициализация Git репозитория (если еще не инициализирован)
```bash
git init
git add .
git commit -m "Initial commit"
```

### 3.2 Создание удаленного репозитория
На сервере:
```bash
ssh user@your-server-ip
sudo mkdir -p /var/git/nextjs-app.git
cd /var/git/nextjs-app.git
sudo git init --bare
sudo chown -R $USER:$USER /var/git/nextjs-app.git
exit
```

### 3.3 Добавление удаленного репозитория
На локальной машине:
```bash
git remote add production user@your-server-ip:/var/git/nextjs-app.git
git push production main
```

### 3.4 Настройка хуков для автоматического развертывания
На сервере создайте хук:
```bash
ssh user@your-server-ip
nano /var/git/nextjs-app.git/hooks/post-receive
```

Добавьте в хук:
```bash
#!/bin/bash
GIT_REPO=/var/git/nextjs-app.git
TMP_GIT_CLONE=/tmp/nextjs-app
PUBLIC_WWW=/var/www/nextjs-app

rm -rf $TMP_GIT_CLONE
git clone $GIT_REPO $TMP_GIT_CLONE

cd $PUBLIC_WWW
git pull $GIT_REPO main

cd $PUBLIC_WWW
npm install
npm run build
npm run db:push
npm run db:generate

pm2 restart nextjs-app

rm -rf $TMP_GIT_CLONE
```

Сделайте хук исполняемым:
```bash
chmod +x /var/git/nextjs-app.git/hooks/post-receive
```

## Метод 4: Использование SFTP

### 4.1 Использование FileZilla
1. Откройте FileZilla
2. Введите данные подключения:
   - Хост: sftp://your-server-ip
   - Имя пользователя: your-username
   - Пароль: your-password
   - Порт: 22
3. Перетащите файлы проекта в `/var/www/nextjs-app/`

### 4.2 Использование командной строки
```bash
# Подключение
sftp user@your-server-ip

# В SFTP сессии
cd /var/www/nextjs-app
put -r ./
exit
```

## Метод 5: Использование Docker (альтернативный вариант)

### 5.1 Создание Dockerfile
Если у вас еще нет Dockerfile, создайте его:
```dockerfile
FROM node:20-alpine

WORKDIR /app

# Копирование package.json и package-lock.json
COPY package*.json ./

# Установка зависимостей
RUN npm ci --only=production

# Копирование исходного кода
COPY . .

# Сборка приложения
RUN npm run build

# Экспонирование порта
EXPOSE 3000

# Запуск приложения
CMD ["npm", "start"]
```

### 5.2 Создание docker-compose.yml
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
```

### 5.3 Загрузка и запуск
```bash
# Загрузка файлов
scp -r ./ user@your-server-ip:/var/www/nextjs-app/

# Подключение к серверу
ssh user@your-server-ip

# Переход в директорию проекта
cd /var/www/nextjs-app

# Запуск Docker
docker-compose up -d --build
```

## Проверка после загрузки

После загрузки файлов на сервер, выполните следующие команды:

```bash
# Подключение к серверу
ssh user@your-server-ip

# Переход в директорию проекта
cd /var/www/nextjs-app

# Проверка прав доступа
sudo chown -R $USER:$USER /var/www/nextjs-app
chmod -R 755 /var/www/nextjs-app

# Установка зависимостей
npm install

# Сборка проекта
npm run build

# Настройка базы данных
npm run db:push
npm run db:generate

# Запуск приложения
pm2 start ecosystem.config.js
```

## Решение проблем

### Проблема: Ошибка прав доступа
```bash
sudo chown -R $USER:$USER /var/www/nextjs-app
sudo chmod -R 755 /var/www/nextjs-app
```

### Проблема: Файлы не загружаются
```bash
# Проверьте доступное место на сервере
df -h

# Проверьте права на директорию
ls -la /var/www/
```

### Проблема: Медленная загрузка
```bash
# Используйте сжатие
rsync -avz --compress ./ user@your-server-ip:/var/www/nextjs-app/

# Или ограничьте пропускную способность
rsync -avz --bwlimit=1000 ./ user@your-server-ip:/var/www/nextjs-app/
```

Выберите метод, который наиболее удобен для вас, и следуйте инструкциям. Рекомендуется использовать метод с Git или RSYNC для удобства последующих обновлений.