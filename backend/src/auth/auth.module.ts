import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthGuard } from './auth.guard';
import { DatabaseModule } from '../database/database.module';
import { AuthController } from './auth.controller';
import { AdminGuard } from './admin.guard';
import { FirebaseModule } from './firebase.module';
import { MaintenanceController } from './maintenance.controller';
import { VerificationService } from './verification.service';

@Module({
  imports: [DatabaseModule, FirebaseModule],
  controllers: [AuthController, MaintenanceController],
    providers: [AuthService, AuthGuard, AdminGuard, VerificationService],
    exports: [AuthService, AuthGuard, AdminGuard, VerificationService],
})
export class AuthModule { }
