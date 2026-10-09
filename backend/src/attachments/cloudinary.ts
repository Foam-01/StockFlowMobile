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

/** Every photo for a transaction lives in its own folder. */
export function txFolder(txId: string): string {
  return `stockflow/transactions/${txId}`;
}

/**
 * Checks that a client-reported upload really is an image in this
 * transaction's folder on our Cloudinary account, so a client can't attach
 * arbitrary URLs. Returns an error message, or null when valid.
 */
export function validateUploadedAsset(
  asset: { publicId: string; url: string },
  { cloudName, txId }: { cloudName: string; txId: string },
): string | null {
  const folder = `${txFolder(txId)}/`;
  if (!asset.publicId.startsWith(folder)) {
    return 'Image is not in this transaction’s folder';
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
