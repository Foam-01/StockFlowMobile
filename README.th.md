# StockFlow Mobile

[English](README.md) | **ภาษาไทย**

แอปจัดการสต็อกสินค้าบนมือถือ — รับเข้า / เบิกออก / ปรับยอด พร้อมประวัติการเคลื่อนไหวของสินค้า

- **Mobile:** Flutter · Riverpod · go_router · Dio
- **Backend:** NestJS · Prisma · PostgreSQL (Neon) · JWT
- โปรเจกต์สำหรับ portfolio / demo รันบนเครื่อง local

## ฟีเจอร์

- เข้าสู่ระบบด้วย JWT แยกสิทธิ์ `ADMIN` / `STAFF` (เก็บ token ด้วย secure storage)
- รายการสินค้า ค้นหา และค้นจากบาร์โค้ด พร้อมป้ายแสดงสถานะสต็อก
- เอกสารเคลื่อนไหวสต็อก 3 แบบ: `RECEIVE` (รับเข้า), `ISSUE` (เบิกออก), `ADJUST` (ปรับยอด)
- เอกสารมีสถานะ `DRAFT` → `CONFIRMED` / `CANCELLED` สต็อกจะเปลี่ยนเมื่อ confirm เท่านั้น
- ประวัติการเคลื่อนไหวและ audit รายสินค้า
- เอกสาร API ด้วย Swagger

## โครงสร้างโปรเจกต์

```
.
├── backend/   # NestJS API
│   ├── prisma/          # schema, migrations, seed
│   └── src/             # auth, products, categories, stock
└── mobile/    # Flutter app
    └── lib/
        ├── core/        # api client, config, router, token storage
        └── features/    # auth, products, operations, history, profile
```

## เริ่มต้นใช้งาน

### สิ่งที่ต้องมี

- Node.js 20+
- Flutter SDK (Dart 3.x)
- ฐานข้อมูล PostgreSQL (แนะนำ [Neon](https://neon.tech) ใช้ฟรี)
- Android Studio + Emulator หรือมือถือ Android

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env      # แล้วใส่ DATABASE_URL, DIRECT_URL, JWT_SECRET
npx prisma migrate deploy
npx prisma db seed        # สร้างบัญชี demo และข้อมูลตัวอย่าง
npm run start:dev
```

API จะรันที่ `http://localhost:3000` และดู Swagger ได้ที่ `http://localhost:3000/docs`

**บัญชี demo** (รหัสผ่านตั้งใน `.env` ผ่าน `SEED_ADMIN_PASSWORD` / `SEED_STAFF_PASSWORD`)

| อีเมล | สิทธิ์ |
|---|---|
| `admin@stockflow.dev` | ADMIN |
| `staff@stockflow.dev` | STAFF |

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter devices                 # ดู id ของเครื่อง
flutter run -d emulator-5554    # Android emulator
```

แอปเลือก URL ของ API ให้อัตโนมัติ (ดู `mobile/lib/core/config.dart`)

| รันบน | API URL |
|---|---|
| Android Emulator | `http://10.0.2.2:3000` |
| Web / Desktop | `http://localhost:3000` |
| มือถือจริง | ต้องระบุ IP ของคอมในวง Wi-Fi เดียวกัน |

รันบนมือถือจริง:

```bash
flutter run --dart-define=API_URL=http://192.168.1.10:3000
```

## API หลัก

| Method | Path | คำอธิบาย |
|---|---|---|
| POST | `/auth/login` | เข้าสู่ระบบ |
| GET | `/auth/me` | ข้อมูลผู้ใช้ปัจจุบัน |
| GET | `/products` | รายการสินค้า |
| GET | `/products/barcode/:barcode` | ค้นสินค้าจากบาร์โค้ด |
| POST / PATCH / DELETE | `/products/:id` | จัดการสินค้า |
| POST | `/transactions` | สร้างเอกสาร (draft) |
| GET | `/transactions` | รายการเอกสาร |
| POST | `/transactions/:id/confirm` | ยืนยันเอกสาร (ตัดสต็อก) |
| POST | `/transactions/:id/cancel` | ยกเลิกเอกสาร |
| GET | `/products/:id/movements` | ประวัติการเคลื่อนไหว |
| GET | `/products/:id/audit` | audit สินค้า |

ดูรายละเอียดทั้งหมดได้ที่ Swagger `/docs`

## การทดสอบ

```bash
cd backend && npm test          # unit tests (Vitest)
cd mobile && flutter test       # widget / unit tests
```
