import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service.js';
import type { AuthUser } from './decorators/index.js';
import { CurrentUser, Public } from './decorators/index.js';
import { LoginDto, RegisterDto } from './dto/auth.dto.js';

/** Slows down password guessing: a few attempts per minute per client. */
const authLimit = {
  default: {
    ttl: 60_000,
    limit: () => Number(process.env.LOGIN_RATE_LIMIT_PER_MINUTE ?? 10),
  },
};

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Throttle(authLimit)
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Public()
  @Throttle(authLimit)
  @Post('login')
  @HttpCode(200)
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @ApiBearerAuth()
  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.auth.me(user.id);
  }
}
