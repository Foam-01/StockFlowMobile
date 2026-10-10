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
  'Installation parts': 'อุปกรณ์ติดตั้ง',
  อะไหล่งานติดตั้ง: 'อุปกรณ์ติดตั้ง',
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

/**
 * The first demo catalog was a convenience store. Rename those products in
 * place (ids, history and documents stay) into the AC installation catalog.
 */
const LEGACY_SKUS: Record<string, string> = {
  'BEV-001': 'INS-005',
  'BEV-002': 'PIP-004',
  'BEV-003': 'REF-001',
  'SNK-001': 'AC-009',
  'SNK-002': 'AC-012',
  'HH-001': 'AC-018',
  'HH-002': 'ELE-001',
  'ST-001': 'INS-006',
  'ST-002': 'ELE-002',
};

async function renameLegacySkus() {
  for (const [from, to] of Object.entries(LEGACY_SKUS)) {
    const exists = await prisma.product.findUnique({ where: { sku: to } });
    if (!exists) {
      await prisma.product.updateMany({
        where: { sku: from },
        // Old consumer photos no longer match; seed:images sets new ones.
        data: { sku: to, barcode: null, imageUrl: null },
      });
    }
  }
}

async function main() {
  await renameLegacy();
  await renameLegacySkus();
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
    'เครื่องปรับอากาศ',
    'ท่อและฉนวน',
    'อุปกรณ์ติดตั้ง',
    'อุปกรณ์ไฟฟ้า',
    'น้ำยาแอร์',
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

  // An AC installation business: units, piping, mounting, electrical and
  // refrigerant. onHand starts at 0; stock only enters via confirmed RECEIVE.
  const products = [
    {
      sku: 'AC-009',
      barcode: '8859000500011',
      name: 'แอร์ติดผนัง 9,000 BTU อินเวอร์เตอร์',
      unit: 'เครื่อง',
      minStock: 3,
      category: 'เครื่องปรับอากาศ',
    },
    {
      sku: 'AC-012',
      barcode: '8859000500028',
      name: 'แอร์ติดผนัง 12,000 BTU อินเวอร์เตอร์',
      unit: 'เครื่อง',
      minStock: 3,
      category: 'เครื่องปรับอากาศ',
    },
    {
      sku: 'AC-018',
      barcode: '8859000500035',
      name: 'แอร์ติดผนัง 18,000 BTU อินเวอร์เตอร์',
      unit: 'เครื่อง',
      minStock: 2,
      category: 'เครื่องปรับอากาศ',
    },
    {
      sku: 'INS-001',
      barcode: '8859000100011',
      name: 'ชุดท่อทองแดง 1/4" + 3/8" (4 ม.)',
      unit: 'ชุด',
      minStock: 5,
      category: 'ท่อและฉนวน',
    },
    {
      sku: 'INS-005',
      barcode: '8859000100059',
      name: 'ฉนวนยางหุ้มท่อ 3/8" (ยาว 2 ม.)',
      unit: 'เส้น',
      minStock: 24,
      category: 'ท่อและฉนวน',
    },
    {
      sku: 'INS-003',
      barcode: '8859000100035',
      name: 'เทปพันท่อแอร์',
      unit: 'ม้วน',
      minStock: 10,
      category: 'ท่อและฉนวน',
    },
    {
      sku: 'PIP-004',
      barcode: '8859000200010',
      name: 'ท่อน้ำทิ้ง PVC 1/2" (4 ม.)',
      unit: 'เส้น',
      minStock: 12,
      category: 'ท่อและฉนวน',
    },
    {
      sku: 'INS-002',
      barcode: '8859000100028',
      name: 'ขาแขวนคอยล์ร้อน',
      unit: 'ชุด',
      minStock: 4,
      category: 'อุปกรณ์ติดตั้ง',
    },
    {
      sku: 'INS-004',
      barcode: '8859000100042',
      name: 'เคเบิลไทร์ (แพ็ก 100)',
      unit: 'แพ็ก',
      minStock: 5,
      category: 'อุปกรณ์ติดตั้ง',
    },
    {
      sku: 'INS-006',
      barcode: '8859000100066',
      name: 'พุกพลาสติกพร้อมสกรู (ถุง 100)',
      unit: 'ถุง',
      minStock: 10,
      category: 'อุปกรณ์ติดตั้ง',
    },
    {
      sku: 'ELE-001',
      barcode: '8859000400014',
      name: 'สายไฟ VCT 2x2.5 ตร.มม. (ม้วน 30 ม.)',
      unit: 'ม้วน',
      minStock: 5,
      category: 'อุปกรณ์ไฟฟ้า',
    },
    {
      sku: 'ELE-002',
      barcode: '8859000400021',
      name: 'เบรกเกอร์ 2P 20A',
      unit: 'ตัว',
      minStock: 5,
      category: 'อุปกรณ์ไฟฟ้า',
    },
    {
      sku: 'REF-001',
      barcode: '8859000300017',
      name: 'น้ำยาแอร์ R32 (ถัง 3 กก.)',
      unit: 'ถัง',
      minStock: 4,
      category: 'น้ำยาแอร์',
    },
  ];
  for (const { category, ...p } of products) {
    await prisma.product.upsert({
      where: { sku: p.sku },
      update: { ...p, categoryId: cat[category] },
      create: { ...p, categoryId: cat[category] },
    });
  }
  // Categories from the old catalog that no longer hold any product.
  await prisma.category.deleteMany({
    where: { name: { notIn: categories }, products: { none: {} } },
  });

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
