import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const production = process.env.NODE_ENV === 'production';

  // Refuse to start in production with the example secret or a short one.
  const secret = process.env.JWT_SECRET ?? '';
  if (production && (secret.length < 32 || secret === 'change-me')) {
    throw new Error('JWT_SECRET must be at least 32 random characters');
  }

  // The mobile app doesn't need CORS; browsers only get the listed origins.
  // Unset: allow all (local development and the web build).
  const origins = process.env.CORS_ORIGINS?.split(',').map((o) => o.trim());
  app.enableCors(origins?.length ? { origin: origins } : undefined);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('StockFlow API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  // API docs are public in development only (or SWAGGER=true).
  if (!production || process.env.SWAGGER === 'true')
    SwaggerModule.setup('docs', app, () =>
      SwaggerModule.createDocument(app, config),
    );

  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
