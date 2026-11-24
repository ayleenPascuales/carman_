import { IsIn } from "class-validator";

export class DecisionSinConductorDTO {

    @IsIn(['Esperar', 'Continuar'])
    decision: 'Esperar' | 'Continuar';
}