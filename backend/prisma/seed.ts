import { PrismaClient, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function upsertUser(
  email: string,
  name: string,
  role: Role,
  password: string,
) {
  const passwordHash = await bcrypt.hash(password, 10);
  return prisma.user.upsert({
    where: { email },
    update: { name, role, passwordHash },
    create: { email, name, role, passwordHash },
  });
}

/** Earlier seeds used English names; rename those rows instead of duplicating. */
const LEGACY_CATEGORIES: Record<string, string> = {
  Beverages: 'เครื่องดื่ม',
  Snacks: 'ขนม',
  Household: 'ของใช้ในบ้าน',
  Stationery: 'เครื่องเขียน',
  'Installation parts': 'อะไหล่งานติดตั้ง',
};
const LEGACY_TEMPLATES: Record<string, string> = {
  'Split-type AC installation': 'ติดตั้งแอร์แยกส่วน',
  'Preventive maintenance (AC)': 'ล้างและบำรุงรักษาแอร์',
  'Network point installation': 'ติดตั้งจุดแลน',
};

async function renameLegacy() {
  for (const [from, to] of Object.entries(LEGACY_CATEGORIES)) {
    const exists = await prisma.category.findUnique({ where: { name: to } });
    if (!exists) {
      await prisma.category.updateMany({
        where: { name: from },
        data: { name: to },
      });
    }
  }
  for (const [from, to] of Object.entries(LEGACY_TEMPLATES)) {
    const exists = await prisma.checklistTemplate.findUnique({
      where: { name: to },
    });
    if (!exists) {
      await prisma.checklistTemplate.updateMany({
        where: { name: from },
        data: { name: to },
      });
    }
  }
}

async function main() {
  await renameLegacy();
  await upsertUser(
    'admin@stockflow.dev',
    'ผู้ดูแลระบบ',
    Role.ADMIN,
    process.env.SEED_ADMIN_PASSWORD ?? 'Admin1234!',
  );
  await upsertUser(
    'staff@stockflow.dev',
    'สมชาย (คลังสินค้า)',
    Role.STAFF,
    process.env.SEED_STAFF_PASSWORD ?? 'Staff1234!',
  );
  // Field operations (synthetic people).
  const techPassword = process.env.SEED_TECH_PASSWORD ?? 'Tech1234!';
  await upsertUser(
    'tech@stockflow.dev',
    'นิรันดร์ (ช่าง)',
    Role.TECHNICIAN,
    techPassword,
  );
  await upsertUser(
    'tech2@stockflow.dev',
    'พลอย (ช่าง)',
    Role.TECHNICIAN,
    techPassword,
  );
  await upsertUser(
    'supervisor@stockflow.dev',
    'กัญญา (หัวหน้างาน)',
    Role.SUPERVISOR,
    process.env.SEED_SUPERVISOR_PASSWORD ?? 'Super1234!',
  );

  const categories = [
    'เครื่องดื่ม',
    'ขนม',
    'ของใช้ในบ้าน',
    'เครื่องเขียน',
    'อะไหล่งานติดตั้ง',
  ];
  const cat: Record<string, string> = {};
  for (const name of categories) {
    const c = await prisma.category.upsert({
      where: { name },
      update: {},
      create: { name },
    });
    cat[name] = c.id;
  }

  // onHand starts at 0 — stock only enters via confirmed RECEIVE transactions.
  const products = [
    {
      sku: 'BEV-001',
      barcode: '8850999320014',
      name: 'น้ำดื่ม 600 มล.',
      unit: 'ขวด',
      minStock: 24,
      category: 'เครื่องดื่ม',
    },
    {
      sku: 'BEV-002',
      barcode: '8851959132012',
      name: 'ชาเขียว 500 มล.',
      unit: 'ขวด',
      minStock: 12,
      category: 'เครื่องดื่ม',
    },
    {
      sku: 'BEV-003',
      barcode: '8850228000016',
      name: 'กาแฟสำเร็จรูป 3in1',
      unit: 'แพ็ก',
      minStock: 10,
      category: 'เครื่องดื่ม',
    },
    {
      sku: 'SNK-001',
      barcode: '8850718801015',
      name: 'มันฝรั่งทอดกรอบ 50 ก.',
      unit: 'ถุง',
      minStock: 20,
      category: 'ขนม',
    },
    {
      sku: 'SNK-002',
      barcode: '8851727001014',
      name: 'เวเฟอร์',
      unit: 'กล่อง',
      minStock: 10,
      category: 'ขนม',
    },
    {
      sku: 'HH-001',
      barcode: '8850002010013',
      name: 'น้ำยาล้างจาน 500 มล.',
      unit: 'ขวด',
      minStock: 6,
      category: 'ของใช้ในบ้าน',
    },
    {
      sku: 'HH-002',
      barcode: '8850002020012',
      name: 'กระดาษทิชชูม้วน (แพ็ก 6)',
      unit: 'แพ็ก',
      minStock: 8,
      category: 'ของใช้ในบ้าน',
    },
    {
      sku: 'ST-001',
      barcode: '8851234000011',
      name: 'ปากกาลูกลื่นสีน้ำเงิน',
      unit: 'ชิ้น',
      minStock: 50,
      category: 'เครื่องเขียน',
    },
    {
      sku: 'ST-002',
      barcode: '8851234000028',
      name: 'กระดาษ A4 80 แกรม',
      unit: 'รีม',
      minStock: 5,
      category: 'เครื่องเขียน',
    },
    // Materials used by field work orders.
    {
      sku: 'INS-001',
      barcode: '8859000100011',
      name: 'ชุดท่อทองแดง 1/4" + 3/8" (4 ม.)',
      unit: 'ชุด',
      minStock: 5,
      category: 'อะไหล่งานติดตั้ง',
    },
    {
      sku: 'INS-002',
      barcode: '8859000100028',
      name: 'ขาแขวนคอยล์ร้อน',
      unit: 'ชิ้น',
      minStock: 4,
      category: 'อะไหล่งานติดตั้ง',
    },
    {
      sku: 'INS-003',
      barcode: '8859000100035',
      name: 'เทปพันท่อ',
      unit: 'ม้วน',
      minStock: 10,
      category: 'อะไหล่งานติดตั้ง',
    },
    {
      sku: 'INS-004',
      barcode: '8859000100042',
      name: 'เคเบิลไทร์ (แพ็ก 100)',
      unit: 'แพ็ก',
      minStock: 5,
      category: 'อะไหล่งานติดตั้ง',
    },
  ];
  for (const { category, ...p } of products) {
    await prisma.product.upsert({
      where: { sku: p.sku },
      update: { ...p, categoryId: cat[category] },
      create: { ...p, categoryId: cat[category] },
    });
  }

  // Read-only checklist templates; work orders copy the items.
  const templates: {
    name: string;
    description: string;
    items: [string, boolean][];
  }[] = [
    {
      name: 'ติดตั้งแอร์แยกส่วน',
      description: 'คอยล์เย็น คอยล์ร้อน เดินท่อ และทดสอบการทำงาน',
      items: [
        ['ยืนยันตำแหน่งติดตั้งกับลูกค้า', true],
        ['ติดตั้งคอยล์เย็นให้ได้ระดับ', true],
        ['ติดตั้งขาแขวนคอยล์ร้อน', true],
        ['ต่อและหุ้มฉนวนท่อทองแดง', true],
        ['แวคคั่มและตรวจรอยรั่ว', true],
        ['ทดสอบความเย็นและการระบายน้ำ', true],
        ['เก็บกวาดพื้นที่ทำงาน', false],
      ],
    },
    {
      name: 'ล้างและบำรุงรักษาแอร์',
      description: 'เข้าบริการตามรอบ',
      items: [
        ['ล้างฟิลเตอร์', true],
        ['ล้างคอยล์และถาดน้ำทิ้ง', true],
        ['วัดแรงดันน้ำยา', true],
        ['ตรวจจุดต่อไฟฟ้า', true],
        ['จดค่าที่วัดได้ในหมายเหตุ', false],
      ],
    },
    {
      name: 'ติดตั้งจุดแลน',
      description: 'เดินสาย เข้าหัว และทดสอบ',
      items: [
        ['เดินสายและรัดด้วยเคเบิลไทร์', true],
        ['เข้าหัวทั้งสองฝั่ง', true],
        ['ทดสอบด้วยเครื่องเทสสาย', true],
        ['ติดป้ายชื่อจุด', false],
      ],
    },
  ];
  for (const t of templates) {
    await prisma.checklistTemplate.upsert({
      where: { name: t.name },
      update: {
        description: t.description,
        items: {
          updateMany: t.items.map(([title, required], i) => ({
            where: { position: i + 1 },
            data: { title, required },
          })),
        },
      },
      create: {
        name: t.name,
        description: t.description,
        items: {
          create: t.items.map(([title, required], i) => ({
            title,
            required,
            position: i + 1,
          })),
        },
      },
    });
  }

  console.log(
    `Seeded 5 users, 3 checklist templates, ${categories.length} categories, ${products.length} products`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
