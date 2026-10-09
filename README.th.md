# StockFlow Mobile

[English](README.md) | **ภาษาไทย**

[![CI](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml/badge.svg)](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml)

แอปจัดการสต็อกสินค้าบนมือถือ รับเข้า เบิกออก และปรับยอดได้ มีสแกนบาร์โค้ด รูปแนบหลักฐาน Dashboard และประวัติการเคลื่อนไหวของแต่ละสินค้าที่ตรวจสอบย้อนหลังได้

- **Mobile:** Flutter · Riverpod · go_router · Dio · mobile_scanner · sqflite
- **Backend:** NestJS · Prisma · PostgreSQL (Neon) · JWT · Cloudinary
- โปรเจกต์สำหรับ portfolio / demo รันบนเครื่อง local

| Dashboard | สินค้า | สินค้าและประวัติ |
|---|---|---|
| <img src="docs/screenshots/dashboard.png" width="250" alt="Dashboard"> | <img src="docs/screenshots/products.png" width="250" alt="Products"> | <img src="docs/screenshots/product-detail.png" width="250" alt="Product detail with movements"> |

| เอกสารสต็อก | สร้างเอกสาร | เข้าสู่ระบบ |
|---|---|---|
| <img src="docs/screenshots/operations.png" width="250" alt="Stock operations"> | <img src="docs/screenshots/new-operation.png" width="250" alt="New issue form"> | <img src="docs/screenshots/login.png" width="250" alt="Sign in"> |

## ฟีเจอร์

- **สิทธิ์ผู้ใช้:** เข้าสู่ระบบด้วย JWT แยกสิทธิ์ `ADMIN` / `STAFF` เก็บ token ด้วย secure storage
- **Dashboard:** ตัวเลขสรุปสต็อก, กราฟรับเข้าเทียบเบิกออก 7 วัน, สินค้าที่ต้องดูแล, กิจกรรมล่าสุด
- **สินค้า:** ค้นหา, กรองหมวดหมู่และสินค้าใกล้หมด, ป้ายสถานะสต็อก, เลื่อนโหลดเพิ่มอัตโนมัติ
- **สแกนบาร์โค้ด:** สแกนเพื่อเปิดสินค้า หรือสแกนเพิ่มของลงเอกสาร (สแกนซ้ำ = +1)
- **เอกสารสต็อก:** `RECEIVE` (รับเข้า), `ISSUE` (เบิกออก), `ADJUST` (ปรับยอด) มีสถานะ `DRAFT` → `CONFIRMED` / `CANCELLED`
  - สต็อกเปลี่ยนเมื่อ Admin ยืนยันเท่านั้น และไม่มีทางติดลบ ถึงจะยืนยันพร้อมกันหลายคน
  - ส่งเอกสารซ้ำด้วย `clientUuid` เดิม จะไม่เกิดรายการซ้ำ
- **รูปแนบหลักฐาน:** ถ่ายรูปหรือเลือกจากแกลเลอรี อัปโหลดตรงไป Cloudinary ด้วยลายเซ็นจาก server
- **โหมดออฟไลน์:** เอกสารที่บันทึกตอนไม่มีเน็ตจะเข้าคิวใน SQLite แล้ว sync ให้อัตโนมัติโดยไม่เกิดรายการซ้ำ ระหว่างออฟไลน์ยังค้นหาและสแกนสินค้าได้
- **ประวัติและ audit:** ดูการเคลื่อนไหวของแต่ละสินค้าพร้อมยอดคงเหลือสะสม และเทียบ ledger กับยอดในระบบ
- ทุกหน้าจอมีสถานะ loading, ว่าง และ error พร้อมปุ่มลองใหม่
- เอกสาร API ด้วย Swagger

ดูแผนภาพได้ที่ **[docs/architecture.th.md](docs/architecture.th.md)**: ภาพรวมระบบ, ขั้นตอนยืนยันเอกสาร, ขั้นตอนอัปโหลดรูป, การ sync ออฟไลน์ และโครงสร้างข้อมูล

## โครงสร้างโปรเจกต์

```
.
├── .github/workflows/ci.yml   # ตรวจ backend + Flutter, build APK
├── backend/   # NestJS API
│   ├── prisma/          # schema, migrations, seed, ข้อมูลย้อนหลัง demo
│   └── src/             # auth, products, stock, dashboard, attachments
├── docs/      # แผนภาพสถาปัตยกรรม
└── mobile/    # Flutter app
    └── lib/
        ├── core/        # api client, ตั้งค่า server URL, router, widgets
        └── features/    # auth, dashboard, products, operations, history, scanner, offline, profile
```

## เริ่มต้นใช้งาน

### สิ่งที่ต้องมี

- Node.js 22+ (CI ใช้ 24)
- Flutter 3.47+ (Dart 3.13)
- ฐานข้อมูล PostgreSQL (แนะนำ [Neon](https://neon.tech) ใช้ฟรี)
- บัญชี [Cloudinary](https://cloudinary.com) สำหรับรูป (ไม่บังคับ มีแพ็กเกจฟรี)
- มือถือ Android หรือ Emulator

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env      # ใส่ DATABASE_URL, DIRECT_URL, JWT_SECRET, CLOUDINARY_*
npx prisma migrate deploy
npx prisma db seed        # บัญชี demo และสินค้าตัวอย่าง
npm run seed:history      # ไม่บังคับ: ข้อมูลย้อนหลัง 6 วันให้ Dashboard
npm run start:dev
```

- API: `http://localhost:3000`
- Swagger: `http://localhost:3000/docs`
- เช็กสถานะ: `http://localhost:3000/health`

ถ้าไม่ใส่ `CLOUDINARY_*` ทุกอย่างยังใช้ได้ ยกเว้นอัปโหลดรูปที่จะขึ้นว่า "not configured" ส่วน `seed:history` รันซ้ำได้ จะแทนที่ข้อมูล demo ของตัวเองและรักษา ledger ให้ถูกต้อง

**บัญชี demo** (รหัสผ่านตั้งใน `.env` ผ่าน `SEED_ADMIN_PASSWORD` / `SEED_STAFF_PASSWORD`)

| อีเมล | สิทธิ์ | ทำอะไรได้ |
|---|---|---|
| `admin@stockflow.dev` | ADMIN | ทุกอย่าง รวมถึงยืนยันเอกสารและแก้ไขสินค้า |
| `staff@stockflow.dev` | STAFF | สร้าง draft, สแกน, แนบรูปในเอกสารของตัวเอง |

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

**ที่อยู่ server:** ในหน้าเข้าสู่ระบบ กด **Server** เพื่อตั้ง API URL แล้วกด **Test connection** เพื่อทดสอบ ค่าที่ตั้งจะถูกจำไว้ในเครื่อง

| รันบน | API URL |
|---|---|
| Android Emulator | `http://10.0.2.2:3000` (ค่าเริ่มต้น) |
| Web / Desktop | `http://localhost:3000` (ค่าเริ่มต้น) |
| มือถือจริง | `http://<IP ของคอมใน Wi-Fi>:3000` |

มือถือจริงต้องต่อ Wi-Fi วงเดียวกับคอม และต้องเปิด firewall ของคอมให้รับ TCP port 3000 จะใส่ URL ตอน build ด้วย `--dart-define=API_URL=http://192.168.1.10:3000` ก็ได้

### APK

ทุกครั้งที่ push ขึ้น `main` GitHub Actions จะ build APK ให้ ดาวน์โหลดได้จาก artifact **stockflow-apk** ใน [CI run](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml) ล่าสุด หรือ build เองในเครื่อง:

```bash
cd mobile
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

APK นี้เซ็นด้วย debug key ติดตั้งเพื่อ demo ได้ แต่ขึ้น Play Store ไม่ได้

## API หลัก

| Method | Path | คำอธิบาย |
|---|---|---|
| POST | `/auth/login` | เข้าสู่ระบบ |
| GET | `/auth/me` | ข้อมูลผู้ใช้ปัจจุบัน |
| GET | `/dashboard` | ตัวเลขสรุป, ยอด 7 วัน, สินค้าที่ต้องดูแล, กิจกรรมล่าสุด |
| GET | `/products` | รายการ / ค้นหา / กรองสินค้า |
| GET | `/products/barcode/:barcode` | ค้นสินค้าจากบาร์โค้ด |
| POST / PATCH / DELETE | `/products/:id` | จัดการสินค้า (Admin) |
| POST | `/transactions` | สร้าง draft (ส่งซ้ำได้ด้วย `clientUuid`) |
| GET | `/transactions` | รายการเอกสาร |
| POST | `/transactions/:id/confirm` | ยืนยันเอกสารและปรับสต็อก (Admin) |
| POST | `/transactions/:id/cancel` | ยกเลิก draft |
| POST | `/transactions/:id/attachments/signature` | ขอลายเซ็นอัปโหลดรูป |
| POST / DELETE | `/transactions/:id/attachments` | บันทึก / ลบรูป |
| GET | `/products/:id/movements` | ประวัติการเคลื่อนไหวพร้อมยอดคงเหลือสะสม |
| GET | `/products/:id/audit` | เทียบ ledger กับยอดในระบบ (Admin) |
| GET | `/health` | เช็กว่า API ทำงาน (ไม่ต้องล็อกอิน) |

ดูรายละเอียดทั้งหมดได้ที่ Swagger `/docs`

## การทดสอบ

```bash
cd backend && npm test          # unit tests (Vitest): กฎสต็อก, ledger, dashboard, ลายเซ็น, retry
cd mobile && flutter test       # widget / unit tests ทุกหน้าจอและทุกขั้นตอน
```

CI ตรวจทุกครั้งที่ push และเปิด pull request: Backend รัน typecheck, lint, test และ build ส่วนแอปรันตรวจ format, analyze และ test

## Demo

<!-- ใส่ลิงก์วิดีโอสั้นๆ ตรงนี้ (เช่น YouTube / Google Drive) -->
_วิดีโอ demo เร็วๆ นี้_
