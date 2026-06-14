# 趣玩星球 · 全栈落地路线图

## 总览（四个阶段）

| 阶段 | 目标 | 状态 |
|------|------|------|
| **Phase 1** | PostgreSQL + 用户认证 + 商品/轮播 API + Flutter 对接 | 已完成 |
| **Phase 2** | 购物车、收藏、浏览记录、优惠券、通知 | 已完成 |
| **Phase 3** | 订单、地址、假支付/真支付预留 | 进行中 |
| **Phase 4** | 部署上线、HTTPS、图片 OSS、管理后台 | 待开始 |

---

## Phase 1 — 你需要手动完成的步骤

### 1. 安装 PostgreSQL

**方式 A：Docker（推荐）**

```powershell
docker run -d --name funplanet-pg -e POSTGRES_PASSWORD=funplanet123 -e POSTGRES_DB=funplanet -p 5432:5432 postgres:16
```

**方式 B：Windows 安装包**

从 https://www.postgresql.org/download/windows/ 安装，记住 postgres 用户密码。

### 2. 创建数据库（若不用 Docker 默认库）

用 pgAdmin 或 psql 执行：

```sql
CREATE DATABASE funplanet;
```

### 3. 配置 `.env`

复制项目根目录 `.env.example` 为 `.env`（若已有则追加），填写：

```env
DATABASE_URL="postgresql://postgres:funplanet123@127.0.0.1:5432/funplanet?schema=public"
JWT_SECRET="请改成随机长字符串至少32位"
DEEPSEEK_API_KEY=sk-你的key
PORT=3000
```

> Docker 方式用户名 `postgres`，密码 `funplanet123`，库名 `funplanet`。

### 4. 安装后端依赖并初始化数据库

```powershell
cd d:\Code_Project\Android_Studio\funplanet\server
npm install
npm run db:generate
npm run db:migrate
npm run db:seed
npm run dev
```

看到 `趣玩星球 API 已启动: http://127.0.0.1:3000` 即成功。

### 5. 验证 API

浏览器或 curl：

- http://127.0.0.1:3000/api/health
- http://127.0.0.1:3000/api/products
- http://127.0.0.1:3000/api/banners

### 6. Flutter 真机调试（可选）

1. 电脑与手机同一 WiFi
2. `ipconfig` 查看 IPv4（如 `192.168.1.100`）
3. 修改 `lib/config/local_api_host.dart` 中 `kLocalApiHostOverride`
4. **Hot Restart** App

---

## Phase 1 完成后 App 行为

- 登录/注册 → 调用后端 JWT 接口
- 商品列表 → 从 PostgreSQL 读取（失败时回退本地 catalog）
- 轮播图元数据 → 从 API 读取（图片仍在 App 内 assets）
- 小豆 AI → 仍走现有 `/api/chat`

---

## Phase 2 — 购物车 / 收藏 / 浏览记录 / 优惠券 / 通知（进行中）

### 你需要手动完成的步骤

```powershell
# 1. 确保 PostgreSQL 在跑
docker start funplanet-pg

# 2. 迁移 + 种子（server 目录）
cd D:\Code_Project\Android_Studio\funplanet\server
npm run db:generate
npm run db:migrate:phase2
npm run db:seed

# 3. 重启后端（若已在跑，Ctrl+C 后重开）
npm run dev

# 4. Flutter：Hot Restart；模拟器/真机先跑 adb-reverse
cd ..
powershell -ExecutionPolicy Bypass -File scripts\adb-reverse.ps1
```

### 验证 API（需先登录拿 token）

- `GET /api/cart`（Bearer token）
- `GET /api/favorites`
- `GET /api/browse-history`
- `GET /api/coupons`
- `GET /api/notifications`

### Phase 2 完成后 App 行为

- 登录后自动从云端拉取：购物车、收藏、浏览记录、优惠券、通知
- 上述操作实时同步到 PostgreSQL（失败时回退本地并静默重拉）
- 演示账号 `13800138000` seed 含：4 个收藏、2 张券（c2 可用 / c3 已用）、4 条通知

---

## Phase 3 — 订单 / 地址 / 假支付

### 你需要手动完成的步骤

```powershell
docker start funplanet-pg

cd D:\Code_Project\Android_Studio\funplanet\server
npm run db:generate
npm run db:migrate:phase3
npm run db:seed

# 重启后端
npm run dev
```

Flutter：adb-reverse → Hot Restart → 登录验证。

### 验证

- `GET /api/addresses` — 演示账号 2 条地址
- 购物车结算 — 服务端算价、清空购物车、生成订单
- `GET /api/orders` — 可看到新订单
- `POST /api/orders/:id/pay` — 假支付（`payNow:false` 下单时用）

### App 行为

- 地址管理从云端读取，「设为默认」同步后端
- 结算走 `POST /api/orders`：服务端按 DB 价格算 `subtotal/total`，假支付直接 `paid`
- 订单列表从云端拉取；退出登录恢复本地 mock 订单

---

## Phase 4 预览

- 云服务器 + Nginx + 域名 HTTPS + 商品图 OSS + 管理后台

每阶段开始前会再给出对应「手动步骤清单」。
