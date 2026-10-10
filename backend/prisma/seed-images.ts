/**
 * Demo product photos. Downloads freely licensed images from Wikimedia
 * Commons, uploads them to Cloudinary (stockflow/products/<sku>) and stores a
 * square, auto-cropped URL on each product. Credits: docs/image-credits.md.
 *
 * Re-runnable: uploads overwrite the same public_id.
 */
import { PrismaClient } from '@prisma/client';
import { signParams } from '../src/attachments/cloudinary.js';

process.loadEnvFile?.('.env');

const prisma = new PrismaClient();
const UA = 'StockFlowDemo/1.0 (portfolio project)';

/** SKU -> Commons file title. */
const IMAGES: Record<string, string> = {
  'AC-009': 'File:HYUNDAI - Air conditioner mini split (model BMS-12HD).jpg',
  'AC-012': 'File:Panasonic AIR CONDITIONER INDOOR UNIT CS-C10KJ2.jpg',
  'AC-018': 'File:Modern split-type air conditioner at a school.jpg',
  'INS-001': 'File:Copper pipes with and without fibreglass insulation asj.jpg',
  'INS-002': 'File:Mitsubishi Electric aircon outdoor unit PU24NEK.jpg',
  'INS-003': 'File:Electrical-Insulation-Tape 122912-480x360 (4999892165).jpg',
  'INS-004': 'File:Cable ties.jpg',
  'INS-005': 'File:Air conditioner armaflex insulation.jpg',
  'INS-006': 'File:Tasselli wall plug.jpg',
  'PIP-004': 'File:1 inch PVC Valve and pipe-IMG 1061.jpg',
  'ELE-001': 'File:Electric guide 3×2.5 mm.jpg',
  'ELE-002': 'File:Circuit breaker 2 pole on DIN rail.JPG',
  'REF-001': 'File:Refillable refrigerant cylinder.png',
};

async function commonsImage(title: string): Promise<Buffer> {
  const api = new URL('https://commons.wikimedia.org/w/api.php');
  api.search = new URLSearchParams({
    action: 'query',
    format: 'json',
    titles: title,
    prop: 'imageinfo',
    iiprop: 'url',
    iiurlwidth: '800',
  }).toString();
  const meta = (await (
    await fetch(api, { headers: { 'User-Agent': UA } })
  ).json()) as {
    query: { pages: Record<string, { imageinfo?: { thumburl: string }[] }> };
  };
  const info = Object.values(meta.query.pages)[0]?.imageinfo?.[0];
  if (!info) throw new Error(`Not found on Commons: ${title}`);
  const res = await fetch(info.thumburl, { headers: { 'User-Agent': UA } });
  if (!res.ok) throw new Error(`Download failed (${res.status}): ${title}`);
  return Buffer.from(await res.arrayBuffer());
}

async function upload(sku: string, image: Buffer): Promise<string> {
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  const apiKey = process.env.CLOUDINARY_API_KEY;
  const apiSecret = process.env.CLOUDINARY_API_SECRET;
  if (!cloudName || !apiKey || !apiSecret) {
    throw new Error('CLOUDINARY_* is not set in .env');
  }
  const params = {
    public_id: `stockflow/products/${sku.toLowerCase()}`,
    overwrite: 'true',
    timestamp: Math.floor(Date.now() / 1000),
  };
  const form = new FormData();
  for (const [k, v] of Object.entries(params)) form.append(k, String(v));
  form.append('api_key', apiKey);
  form.append('signature', signParams(params, apiSecret));
  form.append('file', `data:image/jpeg;base64,${image.toString('base64')}`);

  const res = await fetch(
    `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
    { method: 'POST', body: form },
  );
  const body = (await res.json()) as {
    secure_url?: string;
    error?: { message: string };
  };
  if (!res.ok || !body.secure_url) {
    throw new Error(
      `Upload failed for ${sku}: ${body.error?.message ?? res.status}`,
    );
  }
  // Square thumbnail, cropped around the subject, modern format.
  return body.secure_url.replace(
    '/image/upload/',
    '/image/upload/c_fill,g_auto,w_400,h_400,f_auto,q_auto/',
  );
}

async function main() {
  for (const [sku, title] of Object.entries(IMAGES)) {
    const product = await prisma.product.findUnique({ where: { sku } });
    if (!product) {
      console.warn(`skip ${sku}: no such product`);
      continue;
    }
    // Wikimedia rate-limits bursts of API calls.
    await new Promise((r) => setTimeout(r, 1500));
    const url = await upload(sku, await commonsImage(title));
    await prisma.product.update({ where: { sku }, data: { imageUrl: url } });
    console.log(`${sku} -> ${url}`);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
