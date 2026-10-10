import { createHash } from 'node:crypto';

/**
 * Cloudinary signed-upload helpers. Pure functions (no SDK) so the rules are
 * unit-testable; the API secret never leaves the server.
 */

export interface CloudinaryConfig {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
}

/**
 * Cloudinary signature: params sorted by key, joined as `k=v&k=v`, with the
 * API secret appended, SHA-1 hex. (file, api_key, resource_type and
 * cloud_name are never signed.)
 */
export function signParams(
  params: Record<string, string | number>,
  apiSecret: string,
): string {
  const toSign = Object.keys(params)
    .filter((k) => params[k] !== '' && params[k] !== undefined)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&');
  return createHash('sha1')
    .update(toSign + apiSecret)
    .digest('hex');
}

/** Image types accepted for evidence photos. */
export const ALLOWED_FORMATS = 'jpg,jpeg,png,webp,heic';

/** Oversized photos are shrunk by Cloudinary on arrival (keeps aspect). */
export const INCOMING_TRANSFORMATION = 'c_limit,w_2000,h_2000';

/**
 * Parameters for a signed upload into a transaction's folder. Everything
 * here is covered by the signature, so a client that drops or changes any
 * of them (e.g. to upload a PDF or skip the resize) is rejected by
 * Cloudinary. Cloudinary also rejects signatures older than one hour.
 */
export function uploadParams(txId: string, now = Date.now()) {
  return folderUploadParams(txFolder(txId), now);
}

/** Same signed limits, for any folder (stock documents, work orders). */
export function folderUploadParams(folder: string, now = Date.now()) {
  return {
    allowed_formats: ALLOWED_FORMATS,
    folder,
    timestamp: Math.floor(now / 1000),
    transformation: INCOMING_TRANSFORMATION,
  };
}

/** Every photo for a transaction lives in its own folder. */
export function txFolder(txId: string): string {
  return `stockflow/transactions/${txId}`;
}

/** Evidence photos for a work order. */
export function workOrderFolder(workOrderId: string): string {
  return `stockflow/work-orders/${workOrderId}`;
}

/**
 * Checks that a client-reported upload really is an image in this
 * transaction's folder on our Cloudinary account, so a client can't attach
 * arbitrary URLs. Returns an error message, or null when valid.
 */
export function validateUploadedAsset(
  asset: { publicId: string; url: string },
  ctx: { cloudName: string } & ({ txId: string } | { folder: string }),
): string | null {
  const { cloudName } = ctx;
  const folder = `${'folder' in ctx ? ctx.folder : txFolder(ctx.txId)}/`;
  if (!asset.publicId.startsWith(folder)) {
    return 'Image is not in the expected folder';
  }
  if (asset.publicId.includes('..')) return 'Invalid image id';

  let url: URL;
  try {
    url = new URL(asset.url);
  } catch {
    return 'Invalid image URL';
  }
  if (url.protocol !== 'https:' || url.hostname !== 'res.cloudinary.com') {
    return 'Image must be hosted on Cloudinary';
  }
  if (!url.pathname.startsWith(`/${cloudName}/image/upload/`)) {
    return 'Image is not from this Cloudinary account';
  }
  if (!url.pathname.includes(`/${asset.publicId}.`)) {
    return 'Image URL does not match its id';
  }
  return null;
}

/** Deletes an image from Cloudinary (signed Upload API call). */
export async function destroyAsset(publicId: string, c: CloudinaryConfig) {
  const params = {
    public_id: publicId,
    timestamp: Math.floor(Date.now() / 1000),
  };
  const body = new URLSearchParams({
    public_id: publicId,
    timestamp: String(params.timestamp),
    api_key: c.apiKey,
    signature: signParams(params, c.apiSecret),
  });
  const res = await fetch(
    `https://api.cloudinary.com/v1_1/${c.cloudName}/image/destroy`,
    { method: 'POST', body },
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
}

/** Reads Cloudinary settings; null when photo upload isn't configured. */
export function cloudinaryFromEnv(
  get: (key: string) => string | undefined,
): CloudinaryConfig | null {
  const cloudName = get('CLOUDINARY_CLOUD_NAME');
  const apiKey = get('CLOUDINARY_API_KEY');
  const apiSecret = get('CLOUDINARY_API_SECRET');
  return cloudName && apiKey && apiSecret
    ? { cloudName, apiKey, apiSecret }
    : null;
}
