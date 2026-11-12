import { IsDateString, IsIn } from "class-validator";

export class CrearReservaDto {

    @IsDateString()
    fechaInicioServicio: string;

    @IsIn(['08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM', '6:00 PM'])
    horaInicioServicio: string;

    @IsDateString()
    fechaFinServicio: string;

    @IsIn(['08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM', '6:00 PM'])
    horaFinServicio: string;

}