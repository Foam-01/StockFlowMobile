import {
  ArgumentsHost,
  CallHandler,
  Catch,
  ExceptionFilter,
  ExecutionContext,
  HttpException,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { map, type Observable } from 'rxjs';

/**
 * Thai translations of the API's user-facing messages.
 *
 * Services keep throwing English (the API's default and what logs and tests
 * read); translation happens at the edge when the client sends
 * `Accept-Language: th`. Unknown messages pass through unchanged.
 */
const EXACT: Record<string, string> = {
  'Assignee must be a technician': 'ผู้รับงานต้องเป็นช่างเทคนิค',
  'Cancelled transactions cannot have photos':
    'เอกสารที่ยกเลิกแล้วแนบรูปไม่ได้',
  'Category already exists': 'มีหมวดหมู่นี้อยู่แล้ว',
  'Checklist item not found': 'ไม่พบรายการเช็กลิสต์',
  'Checklist template not found': 'ไม่พบแม่แบบเช็กลิสต์',
  'Each product may appear once in materials':
    'สินค้าแต่ละรายการใส่ในรายการวัสดุได้ครั้งเดียว',
  'Email already registered': 'อีเมลนี้ลงทะเบียนแล้ว',
  'Insufficient role': 'สิทธิ์ไม่เพียงพอ',
  'Invalid category, or product is referenced by stock transactions':
    'หมวดหมู่ไม่ถูกต้อง หรือสินค้านี้ถูกใช้ในเอกสารสต็อกแล้ว',
  'Invalid email or password': 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
  'Invalid or expired token': 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่',
  'Missing bearer token': 'กรุณาเข้าสู่ระบบ',
  'No product with this barcode': 'ไม่พบสินค้าที่มีบาร์โค้ดนี้',
  'One or more products do not exist': 'มีสินค้าบางรายการที่ไม่มีอยู่ในระบบ',
  'Only DRAFT transactions can be cancelled':
    'ยกเลิกได้เฉพาะเอกสารร่างเท่านั้น',
  'Only DRAFT transactions can be confirmed':
    'ยืนยันได้เฉพาะเอกสารร่างเท่านั้น',
  'Only ISSUE or RECEIVE documents can be linked to a work order':
    'ผูกกับใบงานได้เฉพาะเอกสารรับเข้าหรือเบิกออก',
  'Only the creator or an admin can cancel':
    'ยกเลิกได้เฉพาะผู้สร้างเอกสารหรือผู้ดูแลระบบ',
  'Only the creator or an admin can change photos':
    'แก้ไขรูปได้เฉพาะผู้สร้างเอกสารหรือผู้ดูแลระบบ',
  'Photo not found': 'ไม่พบรูป',
  'Photo upload is not configured on the server':
    'เซิร์ฟเวอร์ยังไม่ได้ตั้งค่าการอัปโหลดรูป',
  'Product not found': 'ไม่พบสินค้า',
  'Reviewer must be a supervisor': 'ผู้ตรวจงานต้องเป็นหัวหน้างาน',
  'Transaction not found': 'ไม่พบเอกสาร',
  'User not found': 'ไม่พบผู้ใช้',
  'Work order can no longer be reassigned':
    'ใบงานนี้เปลี่ยนผู้รับผิดชอบไม่ได้แล้ว',
  'Work order is no longer in progress': 'ใบงานไม่ได้อยู่ระหว่างดำเนินการแล้ว',
  'Work order is not ready to submit': 'ใบงานยังไม่พร้อมส่งตรวจ',
  'Work order not found': 'ไม่พบใบงาน',
  'You are not allowed to do this': 'คุณไม่มีสิทธิ์ทำรายการนี้',
  'Validation failed (uuid is expected)': 'รหัสอ้างอิงไม่ถูกต้อง',
  Unauthorized: 'กรุณาเข้าสู่ระบบ',
  'clientUuid already used': 'รหัสเอกสารนี้ถูกใช้แล้ว',
  'ThrottlerException: Too Many Requests':
    'มีคำขอมากเกินไป กรุณารอสักครู่แล้วลองใหม่',
};

const STATUS: Record<string, string> = {
  open: 'รอเริ่มงาน',
  'in progress': 'กำลังทำ',
  in_progress: 'กำลังทำ',
  submitted: 'ส่งตรวจแล้ว',
  'needs revision': 'ต้องแก้ไข',
  needs_revision: 'ต้องแก้ไข',
  approved: 'อนุมัติแล้ว',
  cancelled: 'ยกเลิกแล้ว',
};

const ACTION: Record<string, string> = {
  start: 'เริ่มงาน',
  submit: 'ส่งตรวจ',
  approve: 'อนุมัติ',
  requestChanges: 'ขอให้แก้ไข',
  cancel: 'ยกเลิก',
};

const status = (s: string) => STATUS[s] ?? s;

const PATTERNS: [RegExp, (...m: string[]) => string][] = [
  [/^Checklist: "(.+)" is not done$/, (t) => `เช็กลิสต์ “${t}” ยังไม่เสร็จ`],
  [
    /^Photo required: (before|after|other) work$/,
    (c) =>
      `ต้องมีรูป${{ before: 'ก่อนทำงาน', after: 'หลังทำงาน', other: 'อื่น ๆ' }[c]}`,
  ],
  [
    /^Work order is (.+); cannot (\w+)$/,
    (s, a) => `ใบงานอยู่ในสถานะ “${status(s)}” จึง${ACTION[a] ?? a}ไม่ได้`,
  ],
  [
    /^Work order is (.+); materials can no longer be linked$/,
    (s) => `ใบงานอยู่ในสถานะ “${status(s)}” ผูกวัสดุเพิ่มไม่ได้แล้ว`,
  ],
  [
    /^Not possible while the work order is (.+)$/,
    (s) => `ทำไม่ได้ขณะใบงานอยู่ในสถานะ “${status(s)}”`,
  ],
  [
    /^At most (\d+) photos per (transaction|work order)$/,
    (n, w) =>
      `แนบรูปได้ไม่เกิน ${n} รูปต่อ${w === 'transaction' ? 'เอกสาร' : 'ใบงาน'}`,
  ],
  [/^Duplicate value for (.+)$/, (f) => `ค่า ${f} ซ้ำกับที่มีอยู่แล้ว`],
  [
    /^Insufficient stock for product (\S+): on hand (-?\d+), requested (\d+)$/,
    (_id, onHand, req) => `สต็อกไม่พอ: คงเหลือ ${onHand} แต่ต้องการ ${req}`,
  ],
];

export function toThai(message: string): string {
  if (EXACT[message]) return EXACT[message];
  for (const [rx, fn] of PATTERNS) {
    const m = rx.exec(message);
    if (m) return fn(...m.slice(1));
  }
  return message;
}

export function wantsThai(acceptLanguage: string | undefined): boolean {
  return /^\s*th\b/i.test(acceptLanguage ?? '');
}

const tr = (v: unknown): unknown =>
  typeof v === 'string' ? toThai(v) : Array.isArray(v) ? v.map(tr) : v;

/** Translates `message` and `problems` of error responses for Thai clients. */
@Catch(HttpException)
export class LocalizedErrorFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const http = host.switchToHttp();
    const req = http.getRequest<Request>();
    const res = http.getResponse<Response>();
    const status = exception.getStatus();
    const raw = exception.getResponse();
    let body: Record<string, unknown> =
      typeof raw === 'string'
        ? { statusCode: status, message: raw }
        : { ...(raw as Record<string, unknown>) };
    if (wantsThai(req.headers['accept-language'])) {
      body = {
        ...body,
        message: tr(body.message),
        ...(body.problems ? { problems: tr(body.problems) } : {}),
      };
    }
    res.status(status).json(body);
  }
}

/** Translates `submissionProblems` on work-order responses for Thai clients. */
@Injectable()
export class LocalizedResponseInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = ctx.switchToHttp().getRequest<Request>();
    if (!wantsThai(req.headers['accept-language'])) return next.handle();
    return next.handle().pipe(
      map((data: unknown) => {
        if (
          data &&
          typeof data === 'object' &&
          Array.isArray(
            (data as { submissionProblems?: unknown }).submissionProblems,
          )
        ) {
          const d = data as { submissionProblems: string[] };
          return { ...d, submissionProblems: d.submissionProblems.map(toThai) };
        }
        return data;
      }),
    );
  }
}
