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

async function main() {
  await upsertUser(
    'admin@stockflow.dev',
    'Admin',
    Role.ADMIN,
    process.env.SEED_ADMIN_PASSWORD ?? 'Admin1234!',
  );
  await upsertUser(
    'staff@stockflow.dev',
    'Staff',
    Role.STAFF,
    process.env.SEED_STAFF_PASSWORD ?? 'Staff1234!',
  );

  const categories = ['Beverages', 'Snacks', 'Household', 'Stationery'];
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
      name: 'Drinking water 600ml',
      unit: 'bottle',
      minStock: 24,
      category: 'Beverages',
    },
    {
      sku: 'BEV-002',
      barcode: '8851959132012',
      name: 'Green tea 500ml',
      unit: 'bottle',
      minStock: 12,
      category: 'Beverages',
    },
    {
      sku: 'BEV-003',
      barcode: '8850228000016',
      name: 'Instant coffee 3in1',
      unit: 'pack',
      minStock: 10,
      category: 'Beverages',
    },
    {
      sku: 'SNK-001',
      barcode: '8850718801015',
      name: 'Potato chips 50g',
      unit: 'bag',
      minStock: 20,
      category: 'Snacks',
    },
    {
      sku: 'SNK-002',
      barcode: '8851727001014',
      name: 'Wafer biscuits',
      unit: 'box',
      minStock: 10,
      category: 'Snacks',
    },
    {
      sku: 'HH-001',
      barcode: '8850002010013',
      name: 'Dishwashing liquid 500ml',
      unit: 'bottle',
      minStock: 6,
      category: 'Household',
    },
    {
      sku: 'HH-002',
      barcode: '8850002020012',
      name: 'Tissue roll (6 pack)',
      unit: 'pack',
      minStock: 8,
      category: 'Household',
    },
    {
      sku: 'ST-001',
      barcode: '8851234000011',
      name: 'Ballpoint pen blue',
      unit: 'pcs',
      minStock: 50,
      category: 'Stationery',
    },
    {
      sku: 'ST-002',
      barcode: '8851234000028',
      name: 'A4 paper 80gsm',
      unit: 'ream',
      minStock: 5,
      category: 'Stationery',
    },
  ];
  for (const { category, ...p } of products) {
    await prisma.product.upsert({
      where: { sku: p.sku },
      update: { ...p, categoryId: cat[category] },
      create: { ...p, categoryId: cat[category] },
    });
  }

  console.log(
    `Seeded 2 users, ${categories.length} categories, ${products.length} products`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
