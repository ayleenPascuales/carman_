# Avance fase 4 — M2 cliente: reserva, viaje, pagos y reseñas

**Estado: M2 parcial.** M0/M1 siguen abiertos; ver
[PLAN_PANELES_POR_ROL.md](PLAN_PANELES_POR_ROL.md) y
[AVANCE_FASE4_M1.md](AVANCE_FASE4_M1.md).

## Integrado en este corte

- `GET /reservas/:idReserva`: consulta autenticada del detalle relacionado
  con el cliente, conductor o propietario; un ID ajeno responde 404. La lista
  anterior conserva su contrato y el detalle filtra por ID y cuenta.
- `GET /pagos/reservas/:idReserva/orden`: solo el cliente titular consulta
  total, aprobado, anticipo aprobado, saldo, pagos pendientes y estado; no
  devuelve referencias del proveedor. La ausencia de orden devuelve 404.
  Se conservan la generación idempotente de orden y el webhook Sandbox
  preexistentes.
- Flutter conserva `/checkout` como **confirmación de reserva**, con opción
  de solicitar conductor. En el detalle del viaje se ofrecen al cliente las
  decisiones «Esperar/Continuar» cuando falta conductor, y al actor autorizado
  inicio/finalización según el rol. El backend sigue imponiendo reglas de
  licencia, estado, anticipo y saldo: la UI no sustituye esas verificaciones.
- `/trip/:id/payment` muestra la orden autenticada. Permite generar la orden
  de una reserva confirmada, abrir un checkout **solo en Wompi Sandbox** y
  consultar nuevamente el estado. Se valida el host y la ruta HTTPS antes de
  abrir una URL externa. **El retorno del navegador no aprueba un pago**:
  únicamente el webhook y la consulta posterior actualizan la UI.
- El modo demo conserva sus widgets y comportamiento de simulación. No se
  migró ni se escribió en `carmandb`.

## Validación y pendientes

- Build NestJS, 30 suites/137 pruebas backend y 2 suites/8 pruebas HTTP
  simuladas: correctos. Regresiones de saldo/propiedad con dobles SQL:
  correctas.
- 127 pruebas Flutter correctas; build web con `CARMAN_USE_LIVE_API=true`
  correcto. `flutter analyze --no-pub` final: **sin issues**.
- `flutter pub get --offline` descargó `url_launcher` del caché, pero Windows
  informó que para symlinks de plugins necesita Developer Mode (salida 1).
  El build **web** pasó; las plataformas nativas con este plugin siguen sin
  validarse en este entorno.
- Falta completar lector `/payment-order/:id`, edición de viaje, paginación
  del historial, PDF autenticado, reseña separada de conductor y vehículo,
  seguimiento de retorno del checkout y pruebas con webhook Sandbox real
  (aprobado, rechazo, duplicado y monto diferente). La lista de viajes aún
  no se pagina. No se acreditan los recorridos sin/con conductor → pagos →
  finalización sin cuentas y base aisladas autorizadas.

## Despliegue Vercel del 26 de noviembre de 2026

- Producción promovida a `https://carmanapp.vercel.app/`, despliegue
  `dpl_BuxB6YXuD2sghqw7kgNpi8zSZkz2`. Web, `/api/health` y
  `/api/vehiculos/catalogo` respondieron HTTP 200 en el dominio público;
  la orden sin sesión respondió 401. Estas son verificaciones de lectura,
  **no** recorridos de negocio con cuentas reales.
- Antes de promover, una versión protegida devolvió HTTP 500 en catálogo:
  TiDB rechazó parámetros preparados en `LIMIT/OFFSET`. Se corrigió
  interpolando únicamente enteros acotados tras validar la página y se
  repitieron build backend y 9 pruebas dirigidas, además del smoke del
  catálogo en el despliegue corregido.
- No se ejecutaron migraciones ni escrituras de negocio en esta verificación.
  Se retiraron los bypass de protección que la CLI había creado para el
  smoke protegido (conteo final: cero).
