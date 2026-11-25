import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DatabaseModule } from './database/database.module';
import { PersonasModule } from './personas/personas.module';
import { VehiculosModule } from './vehiculos/vehiculos.module';
import { RutasModule } from './rutas/rutas.module';
import { ReservasModule } from './reservas/reservas.module';
import { PagosModule } from './pagos/pagos.module';
import { NotificacionesModule } from './notificaciones/notificaciones.module';
import { CalificacionesModule } from './calificaciones/calificaciones.module';
import { AuthModule } from './auth/auth.module';
import { AdminModule } from './admin/admin.module';
import { ScheduleModule } from '@nestjs/schedule';
import { validateEnv } from './config/validate-env';
import { HealthModule } from './health/health.module';
import { PuntosModule } from './puntos/puntos.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: validateEnv,
    }),
    // Un proceso serverless no ejecuta cron de forma continua.
    ...(process.env.VERCEL ? [] : [ScheduleModule.forRoot()]),
    DatabaseModule,
    HealthModule,
    PuntosModule,
    PersonasModule,
    VehiculosModule,
    RutasModule,
    ReservasModule,
    PagosModule,
    NotificacionesModule,
    CalificacionesModule,
    AuthModule,
    AdminModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule { }
