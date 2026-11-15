import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { PrismaClient } from '@prisma/client';
import { resetUserByPhone } from '../src/utils/reset-user.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const prisma = new PrismaClient();
const phone = process.argv[2] || '13800138000';

async function main() {
  const user = await resetUserByPhone(phone);
  console.log(`已重置账号 ${phone}（${user.nickname}）全部个人数据为首次进入空状态`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
