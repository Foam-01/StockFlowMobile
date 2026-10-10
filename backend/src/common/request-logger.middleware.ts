import { Injectable, Logger, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

/**
 * One line per request: method, path, status, duration and user id.
 * Deliberately never logs headers (Authorization), query strings or bodies,
 * so tokens, passwords and search terms don't end up in logs.
 */
@Injectable()
export class RequestLoggerMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');

  use(req: Request, res: Response, next: NextFunction) {
    const start = process.hrtime.bigint();
    res.on('finish', () => {
      const ms = Number(process.hrtime.bigint() - start) / 1e6;
      const user = (req as Request & { user?: { id: string } }).user?.id;
      const line = `${req.method} ${req.path} ${res.statusCode} ${ms.toFixed(0)}ms${user ? ` user=${user}` : ''}`;
      if (res.statusCode >= 500) this.logger.error(line);
      else if (res.statusCode >= 400) this.logger.warn(line);
      else this.logger.log(line);
    });
    next();
  }
}
