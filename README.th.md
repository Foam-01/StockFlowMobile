# StockFlow Mobile

[English](README.md) | **ภาษาไทย**

[![CI](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml/badge.svg)](https://github.com/Foam-01/StockFlowMobile/actions/workflows/ci.yml)

**จัดการคลังสินค้าและงานภาคสนามในแอปเดียว** ฝ่ายคลังรับเข้า เบิกออก และปรับยอดสต็อก หัวหน้าสร้างใบงาน แล้วช่างไปทำที่หน้างาน ทำ checklist ถ่ายรูปก่อนและหลังทำงาน และเบิกวัสดุจากคลัง จากนั้นหัวหน้างานตรวจและอนุมัติ ทุกการเคลื่อนไหวของสต็อกและทุกขั้นตอนของใบงานตรวจสอบย้อนหลังได้

- **Mobile:** Flutter · Riverpod · go_router · Dio · mobile_scanner · sqflite
- **Backend:** NestJS · Prisma · PostgreSQL (Neon) · JWT · Cloudinary
- โปรเจกต์สำหรับ portfolio / demo รันบนเครื่อง local

| งานของฉันและจำนวนแจ้งเตือน | เช็กลิสต์และสิ่งที่ยังขาด | งานที่ส่งมา | การแจ้งเตือน |
|---|---|---|---|
| <img src="docs/screenshots/wo-tech-list.png" width="200" alt="งานของฉันและจำนวนแจ้งเตือน"> | <img src="docs/screenshots/wo-tech-checklist.png" width="200" alt="เช็กลิสต์และสิ่งที่ยังขาด"> | <img src="docs/screenshots/wo-review-detail.png" width="200" alt="งานที่ส่งมา"> | <img src="docs/screenshots/notifications.png" width="200" alt="การแจ้งเตือน"> |

| ภาพรวมของผู้ดูแลระบบ | รายการสินค้า | รายละเอียดสินค้า | เบิกออกพร้อมยอดคงเหลือหลังเบิก |
|---|---|---|---|
| <img src="docs/screenshots/dashboard.png" width="200" alt="ภาพรวมของผู้ดูแลระบบ"> | <img src="docs/screenshots/products.png" width="200" alt="รายการสินค้า"> | <img src="docs/screenshots/product-detail.png" width="200" alt="รายละเอียดสินค้า"> | <img src="docs/screenshots/new-operation.png" width="200" alt="เบิกออกพร้อมยอดคงเหลือหลังเบิก"> |

| ติ๊กรอซิงก์ ส่งงานไม่ได้ | รอซิงก์ | โหมดมืด | ภาษาอังกฤษ |
|---|---|---|---|
| <img src="docs/screenshots/wo-offline-pending.png" width="200" alt="ติ๊กรอซิงก์ ส่งงานไม่ได้"> | <img src="docs/screenshots/offline-queue.png" width="200" alt="รอซิงก์"> | <img src="docs/screenshots/dark-dashboard.png" width="200" alt="ภาพรวม"> | <img src="docs/screenshots/en-dashboard.png" width="200" alt="ภาพรวม"> |

ภาพหน้าจอทั้งหมด **78 ภาพ** จากแอปที่รันจริง (Android emulator, API และข้อมูลจริง) อยู่ในหัวข้อ [ภาพหน้าจอ](#ภาพหน้าจอ)

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
- การแจ้งเตือนในแอป (มอบหมาย, ส่งตรวจ, ขอแก้ไข, อนุมัติ, ยกเลิก) สร้างพร้อมประวัติ และไม่แจ้งซ้ำ
- เช็กลิสต์ออฟไลน์: งานที่เคยเปิดแล้วดูได้แม้ไม่มีเน็ต ติ๊กและหมายเหตุจะเข้าคิวแล้วซิงก์ทีหลัง และถ้าค่าบน server เปลี่ยนไปแล้ว การแก้ที่เก่ากว่าจะถูกปฏิเสธแทนการเขียนทับ

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
- แอปใช้ได้ทั้ง **ภาษาไทยและอังกฤษ** (Flutter gen-l10n, ฟอนต์ IBM Plex Sans Thai) ใช้ภาษาตามเครื่อง หรือเลือกเองได้ที่หน้า login หรือโปรไฟล์ ข้อความจาก API เป็นภาษาไทยเมื่อส่ง `Accept-Language: th` และข้อมูลตัวอย่างเป็นภาษาไทย

เอกสาร: [สถาปัตยกรรม](docs/architecture.th.md) · [ใบงาน](docs/work-orders.md) · [offline sync](docs/offline-sync.md) · [ความปลอดภัย](docs/security.md) · [การทดสอบ](docs/testing.md) · การตัดสินใจใน [docs/adr](docs/adr)

## ภาพหน้าจอ

### เข้าสู่ระบบ ภาพรวม และโปรไฟล์

| เข้าสู่ระบบ | เข้าสู่ระบบ (อังกฤษ) | ภาพรวมของผู้ดูแลระบบ | กราฟ 7 วันและสินค้าใกล้หมด |
|---|---|---|---|
| <img src="docs/screenshots/login.png" width="190" alt="เข้าสู่ระบบ"> | <img src="docs/screenshots/en-login.png" width="190" alt="เข้าสู่ระบบ (อังกฤษ)"> | <img src="docs/screenshots/dashboard.png" width="190" alt="ภาพรวมของผู้ดูแลระบบ"> | <img src="docs/screenshots/dashboard-attention.png" width="190" alt="กราฟ 7 วันและสินค้าใกล้หมด"> |

| กิจกรรมล่าสุด | พนักงานคลัง | หัวหน้างาน (ไม่มีปุ่มรับ/เบิก) | โปรไฟล์ |
|---|---|---|---|
| <img src="docs/screenshots/dashboard-activity.png" width="190" alt="กิจกรรมล่าสุด"> | <img src="docs/screenshots/dashboard-staff.png" width="190" alt="พนักงานคลัง"> | <img src="docs/screenshots/dashboard-supervisor.png" width="190" alt="หัวหน้างาน (ไม่มีปุ่มรับ/เบิก)"> | <img src="docs/screenshots/profile.png" width="190" alt="โปรไฟล์"> |

| เลือกภาษา | โปรไฟล์ช่าง |
|---|---|
| <img src="docs/screenshots/profile-language.png" width="190" alt="เลือกภาษา"> | <img src="docs/screenshots/profile-technician.png" width="190" alt="โปรไฟล์ช่าง"> |

### สินค้าและการสแกน

| รายการสินค้า | กรองสินค้าใกล้หมด | มุมมองช่าง (3 แท็บ) | รายละเอียดสินค้า |
|---|---|---|---|
| <img src="docs/screenshots/products.png" width="190" alt="รายการสินค้า"> | <img src="docs/screenshots/products-low-stock.png" width="190" alt="กรองสินค้าใกล้หมด"> | <img src="docs/screenshots/products-technician.png" width="190" alt="มุมมองช่าง (3 แท็บ)"> | <img src="docs/screenshots/product-detail.png" width="190" alt="รายละเอียดสินค้า"> |

| ความเคลื่อนไหวล่าสุด | ประวัติสต็อกพร้อมยอดคงเหลือ | สแกนบาร์โค้ด | พิมพ์บาร์โค้ดเอง |
|---|---|---|---|
| <img src="docs/screenshots/product-detail-movements.png" width="190" alt="ความเคลื่อนไหวล่าสุด"> | <img src="docs/screenshots/stock-history.png" width="190" alt="ประวัติสต็อกพร้อมยอดคงเหลือ"> | <img src="docs/screenshots/scanner.png" width="190" alt="สแกนบาร์โค้ด"> | <img src="docs/screenshots/scanner-manual.png" width="190" alt="พิมพ์บาร์โค้ดเอง"> |

### เอกสารสต็อก

| เอกสารทั้งหมด | กรองที่ยืนยันแล้ว | หน้าว่าง | เลือกประเภท |
|---|---|---|---|
| <img src="docs/screenshots/operations.png" width="190" alt="เอกสารทั้งหมด"> | <img src="docs/screenshots/operations-confirmed.png" width="190" alt="กรองที่ยืนยันแล้ว"> | <img src="docs/screenshots/operations-empty.png" width="190" alt="หน้าว่าง"> | <img src="docs/screenshots/new-operation-type.png" width="190" alt="เลือกประเภท"> |

| เลือกสินค้า | เบิกออกพร้อมยอดคงเหลือหลังเบิก | ร่างรอยืนยัน | ยืนยัน (ย้อนกลับไม่ได้) |
|---|---|---|---|
| <img src="docs/screenshots/product-picker.png" width="190" alt="เลือกสินค้า"> | <img src="docs/screenshots/new-operation.png" width="190" alt="เบิกออกพร้อมยอดคงเหลือหลังเบิก"> | <img src="docs/screenshots/operation-draft.png" width="190" alt="ร่างรอยืนยัน"> | <img src="docs/screenshots/operation-confirm-dialog.png" width="190" alt="ยืนยัน (ย้อนกลับไม่ได้)"> |

| ผู้ดูแลระบบยืนยันแล้ว | เอกสารที่ยืนยันแล้ว |
|---|---|
| <img src="docs/screenshots/operation-confirmed.png" width="190" alt="ผู้ดูแลระบบยืนยันแล้ว"> | <img src="docs/screenshots/operation-detail.png" width="190" alt="เอกสารที่ยืนยันแล้ว"> |

### ผู้ดูแลระบบ: ใบงาน

| ใบงานทั้งหมด | สร้างใบงาน | เลือกวันครบกำหนด | งานใหม่ที่มอบหมายแล้ว |
|---|---|---|---|
| <img src="docs/screenshots/wo-admin-list.png" width="190" alt="ใบงานทั้งหมด"> | <img src="docs/screenshots/wo-create.png" width="190" alt="สร้างใบงาน"> | <img src="docs/screenshots/wo-create-due-picker.png" width="190" alt="เลือกวันครบกำหนด"> | <img src="docs/screenshots/wo-admin-detail.png" width="190" alt="งานใหม่ที่มอบหมายแล้ว"> |

| มอบหมาย / ยกเลิก | รอตรวจ | ประวัติการทำงาน | กล่องแจ้งเตือนว่าง |
|---|---|---|---|
| <img src="docs/screenshots/wo-admin-menu.png" width="190" alt="มอบหมาย / ยกเลิก"> | <img src="docs/screenshots/wo-admin-to-review.png" width="190" alt="รอตรวจ"> | <img src="docs/screenshots/wo-activity.png" width="190" alt="ประวัติการทำงาน"> | <img src="docs/screenshots/notifications-admin.png" width="190" alt="กล่องแจ้งเตือนว่าง"> |

### ช่าง: ทำงานหน้างาน

| งานของฉันและจำนวนแจ้งเตือน | การแจ้งเตือน | หลังอ่านแล้ว | งานใหม่ |
|---|---|---|---|
| <img src="docs/screenshots/wo-tech-list.png" width="190" alt="งานของฉันและจำนวนแจ้งเตือน"> | <img src="docs/screenshots/notifications.png" width="190" alt="การแจ้งเตือน"> | <img src="docs/screenshots/notifications-read.png" width="190" alt="หลังอ่านแล้ว"> | <img src="docs/screenshots/wo-tech-new-job.png" width="190" alt="งานใหม่"> |

| เริ่มงานแล้ว | เช็กลิสต์และสิ่งที่ยังขาด | งานพร้อมวัสดุ | หมายเหตุของรายการ |
|---|---|---|---|
| <img src="docs/screenshots/wo-tech-started.png" width="190" alt="เริ่มงานแล้ว"> | <img src="docs/screenshots/wo-tech-checklist.png" width="190" alt="เช็กลิสต์และสิ่งที่ยังขาด"> | <img src="docs/screenshots/wo-tech-detail.png" width="190" alt="งานพร้อมวัสดุ"> | <img src="docs/screenshots/wo-tech-note.png" width="190" alt="หมายเหตุของรายการ"> |

| ประเภทรูป | กล้องหรือคลังภาพ | กำลังอัปโหลด | รูปก่อนทำงาน |
|---|---|---|---|
| <img src="docs/screenshots/wo-tech-add-photo.png" width="190" alt="ประเภทรูป"> | <img src="docs/screenshots/wo-tech-photo-source.png" width="190" alt="กล้องหรือคลังภาพ"> | <img src="docs/screenshots/wo-tech-uploading.png" width="190" alt="กำลังอัปโหลด"> | <img src="docs/screenshots/wo-tech-photo-added.png" width="190" alt="รูปก่อนทำงาน"> |

| ดูรูปเต็มจอ |
|---|
| <img src="docs/screenshots/wo-tech-photo-view.png" width="190" alt="ดูรูปเต็มจอ"> |

### หัวหน้างาน: ตรวจงาน

| คิวตรวจงาน | แจ้งเตือนงานส่งตรวจ | งานที่ส่งมา | ขอให้แก้ไข (ต้องระบุเหตุผล) |
|---|---|---|---|
| <img src="docs/screenshots/wo-review-queue.png" width="190" alt="คิวตรวจงาน"> | <img src="docs/screenshots/notifications-supervisor.png" width="190" alt="แจ้งเตือนงานส่งตรวจ"> | <img src="docs/screenshots/wo-review-detail.png" width="190" alt="งานที่ส่งมา"> | <img src="docs/screenshots/wo-request-changes.png" width="190" alt="ขอให้แก้ไข (ต้องระบุเหตุผล)"> |

| ส่งกลับพร้อมเหตุผล | ประวัติทั้งหมด | งานที่อนุมัติแล้ว | อนุมัติโดยใคร เมื่อไร |
|---|---|---|---|
| <img src="docs/screenshots/wo-sent-back.png" width="190" alt="ส่งกลับพร้อมเหตุผล"> | <img src="docs/screenshots/wo-activity-review.png" width="190" alt="ประวัติทั้งหมด"> | <img src="docs/screenshots/wo-done-list.png" width="190" alt="งานที่อนุมัติแล้ว"> | <img src="docs/screenshots/wo-approved-detail.png" width="190" alt="อนุมัติโดยใคร เมื่อไร"> |

### คลังสินค้า: เบิกวัสดุให้งาน

| ใบงาน (มุมมองคลัง) | แผนเทียบกับที่เบิกแล้ว | เบิกผูกกับใบงาน | สร้างร่างแล้ว |
|---|---|---|---|
| <img src="docs/screenshots/wo-staff-list.png" width="190" alt="ใบงาน (มุมมองคลัง)"> | <img src="docs/screenshots/wo-materials.png" width="190" alt="แผนเทียบกับที่เบิกแล้ว"> | <img src="docs/screenshots/issue-for-work-order.png" width="190" alt="เบิกผูกกับใบงาน"> | <img src="docs/screenshots/issue-for-work-order-saved.png" width="190" alt="สร้างร่างแล้ว"> |

| ผู้ดูแลระบบยืนยัน |
|---|
| <img src="docs/screenshots/operation-linked-draft.png" width="190" alt="ผู้ดูแลระบบยืนยัน"> |

### ออฟไลน์

| รับเข้าตอนออฟไลน์ | บันทึกไว้ในเครื่อง | รอซิงก์ | ซิงก์เมื่อกลับมาออนไลน์ |
|---|---|---|---|
| <img src="docs/screenshots/offline-receive-form.png" width="190" alt="รับเข้าตอนออฟไลน์"> | <img src="docs/screenshots/offline-saved-toast.png" width="190" alt="บันทึกไว้ในเครื่อง"> | <img src="docs/screenshots/offline-queue.png" width="190" alt="รอซิงก์"> | <img src="docs/screenshots/offline-synced.png" width="190" alt="ซิงก์เมื่อกลับมาออนไลน์"> |

| ใบงานจากข้อมูลที่บันทึกไว้ | ติ๊กรอซิงก์ ส่งงานไม่ได้ | ซิงก์แล้ว |
|---|---|---|
| <img src="docs/screenshots/wo-offline.png" width="190" alt="ใบงานจากข้อมูลที่บันทึกไว้"> | <img src="docs/screenshots/wo-offline-pending.png" width="190" alt="ติ๊กรอซิงก์ ส่งงานไม่ได้"> | <img src="docs/screenshots/wo-tech-synced.png" width="190" alt="ซิงก์แล้ว"> |

### โหมดมืด

| ภาพรวม | สินค้า | ใบงาน | รายละเอียดงาน |
|---|---|---|---|
| <img src="docs/screenshots/dark-dashboard.png" width="190" alt="ภาพรวม"> | <img src="docs/screenshots/dark-products.png" width="190" alt="สินค้า"> | <img src="docs/screenshots/dark-jobs.png" width="190" alt="ใบงาน"> | <img src="docs/screenshots/dark-job-detail.png" width="190" alt="รายละเอียดงาน"> |

### ภาษาอังกฤษ

| ภาพรวม | สินค้า | ใบงาน | รายละเอียดงาน |
|---|---|---|---|
| <img src="docs/screenshots/en-dashboard.png" width="190" alt="ภาพรวม"> | <img src="docs/screenshots/en-products.png" width="190" alt="สินค้า"> | <img src="docs/screenshots/en-jobs.png" width="190" alt="ใบงาน"> | <img src="docs/screenshots/en-job-detail.png" width="190" alt="รายละเอียดงาน"> |

| ประวัติ |
|---|
| <img src="docs/screenshots/en-activity.png" width="190" alt="ประวัติ"> |

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
| Backend unit (กฎ: สต็อก, ใบงาน, การแจ้งเตือน, dashboard, ลายเซ็น, retry, คำแปล) | 58 |
| Backend API กับ Postgres จริง (auth, สิทธิ์, สถานะ, การทำงานพร้อมกัน, ส่งซ้ำ, การเชื่อมกับคลัง, การแจ้งเตือน, แก้ไขออฟไลน์) | 62 |
| Flutter widget / unit | 82 |

```bash
cd backend && npm test          # unit tests
cd backend && npm run test:e2e  # เทสต์ API ต้องมี Postgres ในเครื่องที่ล้างได้ (ดู docs/testing.md)
cd mobile && flutter test
```

CI รันทั้งหมดนี้ทุกครั้งที่ push และเปิด pull request พร้อมตรวจ type, lint, format, analyze และ build APK ส่วนที่**ยังไม่ได้ทดสอบ** (บนมือถือจริง, UI แบบครบวงจร) ระบุไว้ใน [docs/testing.md](docs/testing.md)

## ข้อจำกัดที่รู้อยู่

สิ่งที่เวอร์ชันนี้**ยังไม่ได้ทำ** (รายละเอียดอยู่ในเอกสารที่ลิงก์ไว้):

- **ยังไม่ได้ deploy**: รันในเครื่อง (API + Neon + Cloudinary) และ APK เซ็นด้วย debug key จึงเป็นแค่ demo ยังไม่พร้อมขึ้น Play Store
- **ออฟไลน์ได้บางส่วน**: เอกสารร่าง ค้นหาสินค้า และเช็กลิสต์ใบงานใช้ได้ตอนออฟไลน์ ส่วนรูป เริ่มงาน ส่งงาน ตรวจงาน และรายการงานต้องออนไลน์ ([offline-sync.md](docs/offline-sync.md))
- **การแจ้งเตือนมีแค่ในแอป**: ไม่มี push ตัวเลขจะอัปเดตเมื่อดึงรีเฟรชหรือเปิดหน้าการแจ้งเตือน
- **ไม่มีการจองสต็อก**: เบิกวัสดุด้วยเอกสารที่ผูกกับใบงาน ([work-orders.md](docs/work-orders.md))
- **ถ้าจะเปิดสาธารณะ** ยังต้องมี TLS การเพิกถอน token และอัปเกรด Prisma เพื่อแก้ advisory ของ CLI ([security.md](docs/security.md#review-2026-10-12))
- **การทดสอบ**: ยังไม่มีเทสต์บนมือถือจริงหรือ UI แบบครบวงจร สแกนเนอร์และกล้องทดสอบด้วยมือเท่านั้น ([testing.md](docs/testing.md))
- ข้อความจาก server แปลเป็นไทยแล้ว แต่ข้อความ validation ของแต่ละช่องจาก API ยังเป็นภาษาอังกฤษ

## Demo

สคริปต์สำหรับถ่ายวิดีโอ demo อยู่ที่ [docs/demo-storyboard.md](docs/demo-storyboard.md)

<!-- ใส่ลิงก์วิดีโอสั้นๆ ตรงนี้ (เช่น YouTube / Google Drive) -->
