FROM node:20-alpine

RUN apk add --no-cache openssl

WORKDIR /app

COPY server/package*.json ./
RUN npm ci

COPY server/ ./
COPY assets/ /assets/

RUN npx prisma generate

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node src/index.js"]
