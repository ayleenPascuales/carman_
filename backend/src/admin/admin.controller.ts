import { Controller, Get, UseGuards } from "@nestjs/common";
import { AdminService } from './admin.service';
import { AuthGuard } from "../auth/auth.guard";
import { AdminGuard } from "../auth/admin.guard";

@Controller('admin')
@UseGuards(AuthGuard, AdminGuard)
export class AdminController {
    constructor(private readonly adminService: AdminService) { }

    @Get('usuarios')
    obtenerUsuarios() {
        return this.adminService.obtenerUsuarios();
    }

}