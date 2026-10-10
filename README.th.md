# StockFlow Mobile

[English](README.md) | **ภาษาไทย**

[![CI](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml/badge.svg)](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml)

**จัดการคลังสินค้าและงานภาคสนามในแอปเดียว** ฝ่ายคลังรับเข้า เบิกออก และปรับยอดสต็อก หัวหน้าสร้างใบงาน แล้วช่างไปทำที่หน้างาน ทำ checklist ถ่ายรูปก่อนและหลังทำงาน และเบิกวัสดุจากคลัง จากนั้นหัวหน้างานตรวจและอนุมัติ ทุกการเคลื่อนไหวของสต็อกและทุกขั้นตอนของใบงานตรวจสอบย้อนหลังได้

- **Mobile:** Flutter · Riverpod · go_router · Dio · mobile_scanner · sqflite
- **Backend:** NestJS · Prisma · PostgreSQL (Neon) · JWT · Cloudinary
- โปรเจกต์สำหรับ portfolio / demo รันบนเครื่อง local

| ช่าง: รายการงาน | ช่าง: งานที่กำลังทำ | หัวหน้างาน: ตรวจงาน |
|---|---|---|
| <img src="docs/screenshots/wo-tech-list.png" width="250" alt="รายการงานของช่าง"> | <img src="docs/screenshots/wo-tech-detail.png" width="250" alt="งานพร้อม checklist และสิ่งที่ยังขาด"> | <img src="docs/screenshots/wo-review-detail.png" width="250" alt="หัวหน้างานตรวจงานที่ส่งมา"> |

| Dashboard | สินค้า | สินค้าและประวัติ |
|---|---|---|
| <img src="docs/screenshots/dashboard.png" width="250" alt="Dashboard"> | <img src="docs/screenshots/products.png" width="250" alt="สินค้า"> | <img src="docs/screenshots/product-detail.png" width="250" alt="รายละเอียดสินค้าและการเคลื่อนไหว"> |

| เอกสารสต็อก | สร้างเอกสาร | เข้าสู่ระบบ |
|---|---|---|
| <img src="docs/screenshots/operations.png" width="250" alt="เอกสารสต็อก"> | <img src="docs/screenshots/new-operation.png" width="250" alt="ฟอร์มเบิกออก"> | <img src="docs/screenshots/login.png" width="250" alt="เข้าสู่ระบบ"> |

## การทำงานร่วมกัน

1. **Admin** สร้างใบงาน กำหนดสถานที่, template ของ checklist, รูปที่ต้องถ่าย, วัสดุที่ต้องใช้, ช่าง และผู้ตรวจ (ถ้ามี)
2. **ฝ่ายคลัง** เบิกวัสดุด้วยเอกสาร `ISSUE` ที่ผูกกับใบงาน ระบบกรอกจำนวนที่ยังขาดให้อัตโนมัติ สต็อกจะเปลี่ยนเมื่อ Admin ยืนยันเท่านั้น
3. **ช่าง** เริ่มงาน ทำ checklist ใส่หมายเหตุ ถ่ายรูปก่อนและหลังทำงาน แล้วส่งงาน server จะไม่รับจนกว่ารายการและรูปที่บังคับจะครบ
4. **หัวหน้างาน** อนุมัติ หรือส่งกลับให้แก้พร้อมเหตุผล ช่างกลับมาทำต่อแล้วส่งใหม่
5. ทุกขั้นตอนถูกบันทึกเป็นประวัติที่เพิ่มได้อย่างเดียว ลบหรือแก้ไม่ได้

## ฟีเจอร์

**งานภาคสนาม**
- ใบงานมีลำดับสถานะชัดเจน (`OPEN → IN_PROGRESS → SUBMITTED → APPROVED` หรือ `→ NEEDS_REVISION → IN_PROGRESS` และยกเลิกได้พร้อมเหตุผล)
- เปลี่ยนสถานะแต่ละแบบมี endpoint ของตัวเอง server ตรวจทุกครั้ง และบันทึกพร้อมประวัติในคราวเดียว กดซ้ำไม่เกิดผลซ้ำ และถ้าตัดสินใจพร้อมกันจะมีแค่หนึ่งคำสั่งที่สำเร็จ
- checklist คัดลอกจาก template (แก้ template ทีหลังก็ไม่กระทบใบงานที่มีอยู่) มีรูปก่อนและหลังที่บังคับ และแสดงวัสดุที่วางแผนเทียบกับที่เบิกแล้ว พร้อมเตือนเมื่อของไม่พอ
- แอปแยกตามบทบาท: ช่างเห็นเฉพาะงานของตัวเอง, หัวหน้างานเปิดมาเจอคิวตรวจงานก่อน และปุ่มต่างๆ ตรงกับ `allowedActions` ที่ server ส่งมา

**คลังสินค้า**
- **Dashboard:** ตัวเลขสรุปสต็อก, ยอดรับเข้าเทียบเบิกออก 7 วัน, สินค้าที่ต้องดูแล, กิจกรรมล่าสุด
- **สินค้า:** ค้นหา, กรองหมวดหมู่และสินค้าใกล้หมด, รูปสินค้า, เลื่อนโหลดเพิ่มอัตโนมัติ
- **สแกนบาร์โค้ด:** สแกนเพื่อเปิดสินค้า หรือสแกนเพิ่มของลงเอกสาร (สแกนซ้ำ = +1)
- **เอกสารสต็อก:** `RECEIVE`, `ISSUE`, `ADJUST` มีสถานะ `DRAFT` → `CONFIRMED` / `CANCELLED`
  - สต็อกเปลี่ยนเมื่อ Admin ยืนยันเท่านั้น และไม่มีทางติดลบ ถึงจะยืนยันพร้อมกัน
  - ส่งซ้ำด้วย `clientUuid` เดิมไม่เกิดรายการซ้ำ
- **รูปแนบหลักฐาน:** ถ่ายรูปหรือเลือกจากแกลเลอรี อัปโหลดตรงไป Cloudinary ด้วยลายเซ็นจาก server ที่จำกัดชนิดและขนาดไฟล์
- **โหมดออฟไลน์:** เอกสารที่บันทึกตอนไม่มีเน็ตจะเข้าคิวใน SQLite แล้ว sync อัตโนมัติโดยไม่เกิดรายการซ้ำ ระหว่างออฟไลน์ยังค้นหาและสแกนสินค้าได้
- **ประวัติและ audit:** การเคลื่อนไหวของแต่ละสินค้าพร้อมยอดคงเหลือสะสม และเทียบ ledger กับยอดในระบบ

**ด้านวิศวกรรม**
- ตรวจสิทธิ์ที่ server ทุก endpoint รวมถึงระดับรายการ (ช่างขอดูงานของคนอื่นจะได้ `404`)
- rate limit, log ที่ไม่บันทึก token หรือข้อมูลที่ส่ง, ลองใหม่อัตโนมัติเมื่อฐานข้อมูลแบบ serverless หลับอยู่
- ทุกหน้าจอมีสถานะ loading, ว่าง และ error พร้อมปุ่มลองใหม่ และมีเอกสาร API ด้วย Swagger
- แอปใช้ได้ทั้ง **ภาษาไทยและอังกฤษ** (Flutter gen-l10n, ฟอนต์ IBM Plex Sans Thai) ใช้ภาษาตามเครื่อง หรือเลือกเองได้ที่หน้า login หรือโปรไฟล์

เอกสาร: [สถาปัตยกรรม](docs/architecture.th.md) · [ใบงาน](docs/work-orders.md) · [offline sync](docs/offline-sync.md) · [ความปลอดภัย](docs/security.md) · [การทดสอบ](docs/testing.md) · การตัดสินใจใน [docs/adr](docs/adr)

## โครงสร้างโปรเจกต์

```
.
├── .github/workflows/ci.yml   # ตรวจ backend + API (Postgres) + Flutter, build APK
├── backend/   # NestJS API
│   ├── prisma/          # schema, migrations, seeds (บัญชี, ประวัติ, ใบงาน, รูป)
│   ├── src/             # auth, products, stock, dashboard, attachments, work-orders, users
│   └── test/            # เทสต์ API กับ Postgres จริง
├── docs/      # สถาปัตยกรรม, ใบงาน, ความปลอดภัย, การทดสอบ, ADR, ภาพหน้าจอ
└── mobile/    # Flutter app
    └── lib/
        ├── core/        # api client, ตั้งค่า server URL, router, theme, widgets
        └── features/    # auth, dashboard, products, operations, history, scanner,
                         # offline, work_orders, profile
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
npx prisma db seed        # บัญชี demo, สินค้า, template ของ checklist
npm run seed:history      # ไม่บังคับ: ข้อมูลสต็อกย้อนหลัง 6 วัน
npm run seed:work-orders  # ไม่บังคับ: ใบงาน demo สถานะละหนึ่งใบ
npm run seed:images       # ไม่บังคับ: รูปสินค้าขึ้น Cloudinary (ดู docs/image-credits.md)
npm run start:dev
```

- API: `http://localhost:3000`
- Swagger: `http://localhost:3000/docs`
- เช็กสถานะ: `http://localhost:3000/health`

ถ้าไม่ใส่ `CLOUDINARY_*` ทุกอย่างยังใช้ได้ ยกเว้นอัปโหลดรูปที่จะขึ้นว่า "not configured" ส่วน seed สำหรับ demo รันซ้ำได้ จะแทนที่ข้อมูลของตัวเองและรักษา ledger ของสต็อกให้ถูกต้อง

**บัญชี demo** (กดเลือกได้ในหน้าเข้าสู่ระบบ รหัสผ่านอยู่ใน `SEED_*_PASSWORD` ใน `.env`)

| อีเมล | สิทธิ์ | ทำอะไรได้ |
|---|---|---|
| `admin@stockflow.dev` | ADMIN | ทุกอย่าง: ยืนยันเอกสารสต็อก, จัดการสินค้า, สร้าง มอบหมาย และยกเลิกใบงาน, ตรวจงาน |
| `staff@stockflow.dev` | STAFF (คลัง) | สร้าง draft, สแกน, เบิกวัสดุให้ใบงาน, ดูใบงานได้อย่างเดียว |
| `tech@stockflow.dev`, `tech2@stockflow.dev` | TECHNICIAN | เฉพาะงานของตัวเอง: เริ่มงาน, checklist, รูป, ส่งงาน, ดูสินค้าได้อย่างเดียว |
| `supervisor@stockflow.dev` | SUPERVISOR | คิวตรวจงาน: อนุมัติหรือส่งกลับให้แก้, ดูเอกสารสต็อกได้ |

### 2. Mobile

```bash
cd mobile
flutter pub get
flutter run
```

**ที่อยู่ server:** ในหน้าเข้าสู่ระบบ กด **Server** เพื่อตั้ง API URL แล้วกด **Test connection** ค่าที่ตั้งจะถูกจำไว้ในเครื่อง

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
| POST | `/transactions` | สร้าง draft เอกสารสต็อก (ผูกกับใบงานได้) |
| POST | `/transactions/:id/confirm` | ยืนยันเอกสารและปรับสต็อก (Admin) |
| POST | `/transactions/:id/cancel` | ยกเลิก draft |
| GET | `/products/:id/movements` | ประวัติการเคลื่อนไหวพร้อมยอดคงเหลือสะสม |
| GET | `/work-orders` | ใบงานที่ผู้เรียกมีสิทธิ์เห็น (ค้นหา, กรองสถานะ) |
| POST | `/work-orders` | สร้างใบงาน (Admin, ส่งซ้ำได้ด้วย `clientUuid`) |
| GET | `/work-orders/:id` | รายละเอียดพร้อม `allowedActions` และสิ่งที่ยังขาดก่อนส่ง |
| POST | `/work-orders/:id/{start,submit,approve,request-changes,cancel}` | เปลี่ยนสถานะ |
| PUT | `/work-orders/:id/checklist/:itemId` | ติ๊กรายการ / ใส่หมายเหตุ |
| POST / DELETE | `/work-orders/:id/evidence[/:id]` | รูป (signed upload) |
| GET | `/work-orders/:id/events` | ประวัติ (audit trail) |
| GET | `/health` | เช็กว่า API ทำงาน (ไม่ต้องล็อกอิน) |

ดูทั้งหมดได้ที่ Swagger `/docs` และ [docs/work-orders.md](docs/work-orders.md#api)

## การทดสอบ

| ชุดเทสต์ | จำนวน |
|---|---|
| Backend unit (กฎ: สต็อก, ใบงาน, dashboard, ลายเซ็น, retry) | 48 |
| Backend API กับ Postgres จริง (auth, สิทธิ์, สถานะ, การทำงานพร้อมกัน, ส่งซ้ำ, การเชื่อมกับคลัง) | 54 |
| Flutter widget / unit | 65 |

```bash
cd backend && npm test          # unit tests
cd backend && npm run test:e2e  # เทสต์ API ต้องมี Postgres ในเครื่องที่ล้างได้ (ดู docs/testing.md)
cd mobile && flutter test
```

CI รันทั้งหมดนี้ทุกครั้งที่ push และเปิด pull request พร้อมตรวจ type, lint, format, analyze และ build APK ส่วนที่**ยังไม่ได้ทดสอบ** (บนมือถือจริง, UI แบบครบวงจร) ระบุไว้ใน [docs/testing.md](docs/testing.md)

## Demo

<!-- ใส่ลิงก์วิดีโอสั้นๆ ตรงนี้ (เช่น YouTube / Google Drive) -->
_วิดีโอ demo เร็วๆ นี้_
