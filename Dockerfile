# Используем официальный образ Node.js
FROM node:20-alpine

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем package.json и package-lock.json
COPY package*.json ./

# Устанавливаем зависимости
RUN npm ci --only=production

# Копируем остальной код приложения
COPY . .

# Генерируем Prisma
RUN npx prisma generate

# Собираем приложение
RUN npm run build

# Экспонируем порт
EXPOSE 3000

# Создаем директорию для логов
RUN mkdir -p logs

# Устанавливаем tsx глобально
RUN npm install -g tsx

# Запускаем приложение
CMD ["tsx", "server.ts"]