import { createHash } from 'node:crypto';
import { signParams, txFolder, validateUploadedAsset } from './cloudinary.js';

describe('signParams', () => {
  it('matches Cloudinary’s documented example', () => {
    // https://cloudinary.com/documentation/authentication_signatures
    expect(
      signParams(
        {
          eager: 'w_400,h_300,c_pad|w_260,h_200,c_crop',
          public_id: 'sample_image',
          timestamp: 1315060510,
        },
        'abcd',
      ),
    ).toBe('bfd09f95f331f558cbd1320e67aa8d488770583e');
  });

  it('sorts keys and skips empty values', () => {
    const expected = createHash('sha1')
      .update('folder=f&timestamp=1secret')
      .digest('hex');
    expect(signParams({ timestamp: 1, folder: 'f', tags: '' }, 'secret')).toBe(
      expected,
    );
  });
});

describe('validateUploadedAsset', () => {
  const ctx = { cloudName: 'demo', txId: 'tx1' };
  const publicId = `${txFolder('tx1')}/abc123`;
  const url = `https://res.cloudinary.com/demo/image/upload/v1700000000/${publicId}.jpg`;

  it('accepts an image from our folder', () => {
    expect(validateUploadedAsset({ publicId, url }, ctx)).toBeNull();
  });

  it('rejects another transaction’s folder', () => {
    expect(
      validateUploadedAsset({ publicId: `${txFolder('tx2')}/abc`, url }, ctx),
    ).toMatch(/folder/);
  });

  it('rejects other hosts, accounts and mismatched ids', () => {
    expect(
      validateUploadedAsset(
        { publicId, url: url.replace('res.cloudinary.com', 'evil.com') },
        ctx,
      ),
    ).toMatch(/Cloudinary/);
    expect(
      validateUploadedAsset(
        { publicId, url: url.replace('/demo/', '/other/') },
        ctx,
      ),
    ).toMatch(/account/);
    expect(
      validateUploadedAsset(
        { publicId, url: url.replace('abc123', 'zzz') },
        ctx,
      ),
    ).toMatch(/match/);
    expect(
      validateUploadedAsset(
        { publicId, url: url.replace('https:', 'http:') },
        ctx,
      ),
    ).toMatch(/Cloudinary/);
  });

  it('rejects path traversal and garbage URLs', () => {
    expect(
      validateUploadedAsset({ publicId: `${txFolder('tx1')}/../x`, url }, ctx),
    ).not.toBeNull();
    expect(validateUploadedAsset({ publicId, url: 'not a url' }, ctx)).toMatch(
      /URL/,
    );
  });
});
