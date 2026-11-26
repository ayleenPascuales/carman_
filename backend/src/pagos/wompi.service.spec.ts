import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { ServiceUnavailableException } from '@nestjs/common';
import { WompiService, type EventoWompi } from './wompi.service';

describe('WompiService sin configurar', () => {
  let service: WompiService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        WompiService,
        { provide: ConfigService, useValue: { get: () => undefined } },
      ],
    }).compile();
    service = module.get(WompiService);
  });

  it('permite arrancar la aplicación sin credenciales', () => {
    expect(service).toBeDefined();
  });

  it('no genera enlaces de pago sin credenciales', async () => {
    await expect(service.crearCheckout(100, 'prueba'))
      .rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('indica que checkout está deshabilitado sin credenciales', () => {
    expect(() => service.verificarConfiguracionCheckout())
      .toThrow(ServiceUnavailableException);
  });

  it('no valida eventos cuando falta el secreto de firmas', () => {
    expect(service.validarFirmaEvento({
      data: { transaction: {} },
      signature: { checksum: '0'.repeat(64), properties: ['transaction.id'] },
      timestamp: 123,
    } as EventoWompi)).toBe(false);
  });
});

describe('WompiService acepta exclusivamente Sandbox', () => {
  const credencialesPrueba: Record<string, string> = {
    WOMPI_BASE_URL: 'https://sandbox.wompi.co/v1',
    WOMPI_PUBLIC_KEY: 'pub_test_ejemplo',
    WOMPI_PRIVATE_KEY: 'prv_test_ejemplo',
    WOMPI_INTEGRITY_SECRET: 'test_integrity_ejemplo',
    WOMPI_EVENTS_SECRET: 'test_events_ejemplo',
    WOMPI_CHECKOUT_URL: 'https://checkout.wompi.co/p/',
  };

  it('habilita el checkout con las seis variables de prueba', async () => {
    const service = new WompiService({ get: (key: string) => credencialesPrueba[key] } as ConfigService);
    expect(() => service.verificarConfiguracionCheckout()).not.toThrow();
    await expect(service.crearCheckout(100, 'prueba')).resolves.toMatchObject({
      referencia: 'prueba',
      montoEnCentavos: 10000,
    });
  });

  it('rechaza llaves de producción antes de iniciar un cobro', async () => {
    const production = {
      ...credencialesPrueba,
      WOMPI_PUBLIC_KEY: 'pub_prod_ejemplo',
      WOMPI_PRIVATE_KEY: 'prv_prod_ejemplo',
    };
    const service = new WompiService({ get: (key: string) => production[key] } as ConfigService);
    expect(() => service.verificarConfiguracionCheckout()).toThrow(ServiceUnavailableException);
    await expect(service.crearCheckout(100, 'prueba')).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
