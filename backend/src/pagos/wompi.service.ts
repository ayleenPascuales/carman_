
import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { createHash, randomUUID, timingSafeEqual } from 'crypto';

export interface EventoWompi {
    event: string;
    environment: string;
    data: {
        transaction: {
            id: string;
            reference: string;
            amount_in_cents: number;
            currency: string;
            status: string;
            payment_method_type?: string;
        };
    };
    signature: {
        checksum: string;
        properties: string[];
    };
    timestamp: number;
}

@Injectable()
export class WompiService {
    private readonly baseUrl: string;
    private readonly publicKey: string;
    private readonly privateKey: string;
    private readonly integritySecret: string;
    private readonly eventsSecret: string;
    private readonly checkoutUrl: string;

    constructor(private readonly configService: ConfigService) {
        this.baseUrl = this.configService.get<string>('WOMPI_BASE_URL')!;
        this.publicKey = this.configService.get<string>('WOMPI_PUBLIC_KEY')!;
        this.privateKey = this.configService.get<string>('WOMPI_PRIVATE_KEY')!;
        this.integritySecret = this.configService.get<string>('WOMPI_INTEGRITY_SECRET')!;
        this.eventsSecret = this.configService.get<string>('WOMPI_EVENTS_SECRET')!;
        this.checkoutUrl = this.configService.get<string>('WOMPI_CHECKOUT_URL')!;

        if (
            !this.baseUrl ||
            !this.publicKey ||
            !this.privateKey ||
            !this.integritySecret ||
            !this.eventsSecret ||
            !this.checkoutUrl
        ) {
            throw new InternalServerErrorException(
                'Faltan credenciales de configuración de Wompi.',
            );
        }
    }

    async obtenerTokensAceptacion() {
        try {
            const respuesta = await axios.get(
                `${this.baseUrl}/merchants/info`,
                {
                    headers: {
                        'x-merchant-public-key': this.publicKey,
                    },
                },
            );

            const datos = respuesta.data.data;

            return {
                acceptanceToken:
                    datos.presigned_acceptance.acceptance_token,
                acceptanceUrl:
                    datos.presigned_acceptance.permalink,

                personalDataToken:
                    datos.presigned_personal_data_auth.acceptance_token,
                personalDataUrl:
                    datos.presigned_personal_data_auth.permalink,
            };
        } catch {
            throw new InternalServerErrorException(
                'No fue posible obtener los tokens de aceptación de Wompi.',
            );
        }
    }

    async obtenerBancosPSE() {
        try {
            const respuesta = await axios.get(
                `${this.baseUrl}/pse/financial_institutions`,
                {
                    headers: {
                        Authorization: `Bearer ${this.publicKey}`,
                    },
                },
            );

            return respuesta.data.data;
        } catch {
            throw new InternalServerErrorException(
                'No fue posible consultar los bancos disponibles en PSE.',
            );
        }
    }

    private generarFirma(
        referencia: string,
        montoEnCentavos: number,
        moneda = 'COP',
    ): string {
        const cadena = `${referencia}${montoEnCentavos}${moneda}${this.integritySecret}`;

        return createHash('sha256').update(cadena).digest('hex');
    }

    validarFirmaEvento(evento: EventoWompi): boolean {
        try {
            if (
                !evento.signature?.checksum ||
                !Array.isArray(evento.signature.properties) ||
                evento.signature.properties.length === 0 ||
                !Number.isFinite(evento.timestamp)
            ) {
                return false;
            }

            const valores = evento.signature.properties.map((propiedad) => {
                const partes = propiedad.split('.');
                let valor: any = evento.data;

                for (const parte of partes) {
                    valor = valor?.[parte];
                }

                if (valor === undefined || valor === null) {
                    throw new Error('Propiedad de firma inexistente.');
                }

                return String(valor);
            });

            const cadena =
                `${valores.join('')}${evento.timestamp}${this.eventsSecret}`;

            const checksumCalculado = createHash('sha256')
                .update(cadena)
                .digest();

            const checksumRecibido = Buffer.from(
                evento.signature.checksum,
                'hex',
            );

            if (
                checksumRecibido.length !== checksumCalculado.length ||
                !/^[a-fA-F0-9]{64}$/.test(evento.signature.checksum)
            ) {
                return false;
            }

            return timingSafeEqual(checksumCalculado, checksumRecibido);

        } catch {
            return false;
        }
    }

    async crearCheckout(
        monto: number,
        referencia: string,
        redirectUrl: string,
        cliente?: {
            correo?: string;
            nombreCompleto?: string;
            telefono?: string;
        },
    ) {
        if (!Number.isFinite(monto) || monto <= 0) {
            throw new Error('El monto del pago no es válido.');
        }

        if (!referencia || !redirectUrl) {
            throw new Error('Faltan datos para generar el checkout.');
        }

        const montoEnCentavos = Math.round(monto * 100);

        const firma = this.generarFirma(
            referencia,
            montoEnCentavos,
        );

        const parametros = new URLSearchParams({
            'public-key': this.publicKey,
            currency: 'COP',
            'amount-in-cents': String(montoEnCentavos),
            reference: referencia,
            'signature:integrity': firma,
        });

        if (cliente?.correo) {
            parametros.set('customer-data:email', cliente.correo);
        }

        if (cliente?.nombreCompleto) {
            parametros.set('customer-data:full-name', cliente.nombreCompleto);
        }

        if (cliente?.telefono) {
            parametros.set('customer-data:phone-number', cliente.telefono);
            parametros.set('customer-data:phone-number-prefix', '+57');
        }

        const query = parametros.toString().replace(
            'signature%3Aintegrity=',
            'signature:integrity=',
        );

        return {
            referencia,
            monto,
            montoEnCentavos,
            checkoutUrl: `${this.checkoutUrl}?${query}`,
        };
    }


    async consultarTransaccion(idTransaccion: string) {
        try {
            const respuesta = await axios.get(
                `${this.baseUrl}/transactions/${encodeURIComponent(idTransaccion)}`,
                {
                    headers: {
                        Authorization: `Bearer ${this.privateKey}`,
                    },
                },
            );

            return respuesta.data.data;
        } catch {
            throw new InternalServerErrorException(
                'No fue posible consultar la transacción en Wompi.',
            );
        }
    }

    async crearTransaccionNequi(datos: {
        monto: number;
        correo: string;
        celular: string;
        acceptanceToken: string;
        personalDataToken: string;
    }) {
        if (!Number.isFinite(datos.monto) || datos.monto <= 0) {
            throw new Error('El monto del pago no es válido.');
        }

        if (!/^\d{10}$/.test(datos.celular)) {
            throw new Error('El celular de Nequi debe tener 10 dígitos.');
        }

        if (!datos.correo || !datos.acceptanceToken || !datos.personalDataToken) {
            throw new Error('Faltan datos de aceptación o del cliente.');
        }

        const montoEnCentavos = Math.round(datos.monto * 100);
        const referencia = `CARMAN-${randomUUID()}`;

        const firma = this.generarFirma(
            referencia,
            montoEnCentavos,
        );

        const cuerpo = {
            acceptance_token: datos.acceptanceToken,
            accept_personal_auth: datos.personalDataToken,
            amount_in_cents: montoEnCentavos,
            currency: 'COP',
            customer_email: datos.correo,
            reference: referencia,
            signature: firma,
            payment_method_type: 'NEQUI',
            payment_method: {
                type: 'NEQUI',
                phone_number: datos.celular,
            },
        };

        try {
            const respuesta = await axios.post(
                `${this.baseUrl}/transactions`,
                cuerpo,
                {
                    headers: {
                        Authorization: `Bearer ${this.privateKey}`,
                        'Content-Type': 'application/json',
                    },
                },
            );

            return respuesta.data.data;
        } catch (error) {
            if (axios.isAxiosError(error)) {
                console.error(
                    'ERROR DE WOMPI:',
                    JSON.stringify(error.response?.data, null, 2),
                );
            } else {
                console.error('ERROR INTERNO:', error);
            }

            throw new InternalServerErrorException(
                'No fue posible crear la transacción Nequi en Wompi.',
            );
        }
    }

}
