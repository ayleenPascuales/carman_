
import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ReservasService } from '../reservas.service';

@Injectable()
export class TareasReservasService {
    private readonly logger = new Logger(TareasReservasService.name);

    constructor(
        private readonly reservasService: ReservasService
    ) { }

    @Cron(CronExpression.EVERY_30_MINUTES)
    async buscarConductoresPendientes() {
        try {
            const resultado =
                await this.reservasService.buscarYasignarConductor();

            if (resultado.reservasAsignadas.length > 0) {
                this.logger.log(
                    `Se asignaron conductores a ${resultado.reservasAsignadas.length} reservas.`
                );
            }
        } catch (error) {
            this.logger.error(
                'Error al buscar conductores para reservas en espera.',
                error instanceof Error ? error.stack : String(error)
            );
        }
    }
}
