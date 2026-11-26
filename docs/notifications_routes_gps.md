# Reservas, avisos y recorridos (implementación local)

## Contratos

- `GET /notificaciones`, `PATCH /notificaciones/leidas` y
  `PATCH /notificaciones/:id/leida`: bandeja personal, autenticada, con
  comprobación de titularidad y un máximo de 100 avisos recientes.
- Tras registrar cuenta/vehículo/licencia, crear/actualizar/cancelar reserva,
  asignar conductor o procesar un pago Sandbox firmado, se registra un aviso
  interno. Confirmaciones, cancelaciones, falta de conductor y aprobación o
  rechazo de pagos intentan enviar SMS **solo a teléfonos verificados** mediante
  textbee. Un error de entrega no altera el resultado de la reserva o pago.
  Firebase solo sirve para la verificación de correo; **no** se envían correos
  transaccionales ni se afirma que se hayan enviado.
- `GET /vehiculos/catalogo[/:id]`: datos públicos del automóvil y su punto,
  sin placa, documentos ni datos personales del propietario.
- `GET /rutas/vehiculos/:id/punto-cercano`: devuelve exclusivamente el punto
  de recogida activo configurado físicamente para ese vehículo.
  `POST /rutas/vehiculos/:id/punto-cercano` acepta `latitud` y `longitud` en
  el cuerpo **solo** tras solicitar cercanía; devuelve distancia **en línea
  recta**, no la almacena ni incluye coordenadas del usuario en la URL.
- `GET /rutas/reservas/:id`: solo cliente, propietario o conductor de la
  reserva. Devuelve puntos, tarifa estimada y, si está configurado Mapbox
  Directions, distancia vial, tiempo y geometría de calles. Sin Mapbox devuelve
  los puntos y precio **sin inventar** distancia ni trayecto.
- La tarifa de producción es `precioPorDia × días` (mínimo un día), más el
  suplemento de conductor que ya aplica el backend al aceptarlo. **No**
  se añaden kilómetros, IVA, seguros o depósitos ficticios. El Flutter live
  crea una reserva pero no declara un pago completado ni usa tarjetas demo.

## Configuración pendiente

1. Configurar **solo en el backend** `MAPBOX_ACCESS_TOKEN` para rutas viales.
   No publicar este token en Flutter, el repositorio ni parámetros de URL
   enviados al navegador. La clave del SMS (`TEXTBEE_API_KEY`) existente también
   debe permanecer únicamente en el servidor.
2. Revisar con el administrador de la base **solo**
   `backend/migrations/003_ubicacion_compartida.sql` como cambio **optativo y
   aditivo**. No ejecutar `db:migrate` contra `carmandb` ni reaplicar las
   migraciones históricas. Hasta que se aplique de manera controlada,
   `TRIP_LOCATION_ENABLED` permanece ausente/desactivada y el panel indica que
   el seguimiento no está disponible.
3. Una vez verificada la tabla, establecer `TRIP_LOCATION_ENABLED=true` en el
   backend. **No se ha configurado ni desplegado aquí** ninguna de estas
   variables. Los correos de reservas y pagos requieren elegir un proveedor
   transaccional y verificar su dominio; están pendientes por decisión expresa.

## Privacidad del GPS

- El navegador/dispositivo solicita permiso **solo al pulsar** «Cercanía» o
  «Compartir mi ubicación». No hay GPS automático, de fondo ni para obtener
  una ruta vial entre los puntos autorizados.
- El envío voluntario está limitado a un viaje `EnCurso`, a cliente y
  conductor **adultos**, autenticados; el propietario solo ve la ruta prevista,
  nunca la posición precisa. Mientras la pantalla esté visible se actualiza
  cada 25 segundos; al detenerse, salir o poner la app en segundo plano se
  intenta borrar de inmediato.
- Se almacena **una única última posición por persona y reserva**, no un
  historial. Tras dos minutos queda fuera de todas las lecturas; se eliminan
  posiciones caducadas en consultas y el mantenimiento programado diario.
  Si no hay tráfico, una fila caducada puede permanecer físicamente hasta
  ese mantenimiento: antes de activar la función en producción, confirmar la
  política de retención operativa y la ejecución del mantenimiento.
- La reserva debe tener un estado `EnCurso` establecido por el flujo de
  viaje; este cambio no crea un inicio automático de viajes ni permite el
  seguimiento de reservas sin iniciar.

## Verificación sin tocar la base existente

- Backend: `npm run build` y `npm test -- --runInBand` con dependencias aisladas.
- Flutter: `flutter analyze` y `flutter test` con el SDK disponible; la
  compilación web de Vercel usa `flutter pub get --enforce-lockfile` y
  `CARMAN_USE_LIVE_API=true`.

## Variables de entorno para Vercel

Todas se configuran en **Settings → Environment Variables** del proyecto.
**No** se usan variables del shell NVM ni del navegador; el backend las lee
del entorno de despliegue.

| Variable | Obligatoria | Notas |
|----------|:-----------:|-------|
| `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | sí | Conexión TiDB Cloud (MySQL). Puerto por defecto `4000`. |
| `DB_PORT` | opcional | Solo si no usas el `4000`. |
| `DB_SSL_CA` | sí en Vercel | PEM completo del certificado TiDB. En Vercel no se admite `DB_SSL_CA_PATH`. |
| `DB_POOL_SIZE` | opcional | `2` en Vercel; no subir sin ajustar el clúster. |
| `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY` | sí | Del mismo proyecto donde se habilita Email/Password. |
| `FIREBASE_CLIENT_EMAIL` + `FIREBASE_PRIVATE_KEY` | sí | De un servicio de Firebase Admin de ese proyecto. |
| `CORS_ORIGINS` | sí en Vercel | Exacto `https://<proyecto>.vercel.app`, sin `/` final. |
| `CRON_SECRET` | sí en Vercel | Lo envía `Authorization: Bearer …` del Schedule diario. |
| `TEXTBEE_API_KEY` | si se envía SMS | Clave del Android con SIM registrada en textbee. |
| `SMS_OTP_SECRET` | sí con SMS | `openssl rand -hex 32`, 64 caracteres hexadecimales. |
| `WOMPI_BASE_URL`, `WOMPI_PUBLIC_KEY`, `WOMPI_PRIVATE_KEY`, `WOMPI_INTEGRITY_SECRET`, `WOMPI_EVENTS_SECRET`, `WOMPI_CHECKOUT_URL` | sí en Vercel | **Sandbox obligatorio**. Los valores deben empezar con `pub_test_`, `prv_test_`, `test_integrity_`, `test_events_` y `WOMPI_CHECKOUT_URL=https://checkout.wompi.co/p/`. Sin estos valores exactos el webhook rechaza eventos y no se generan órdenes de pago. |
| `MAPBOX_ACCESS_TOKEN` | solo backend | Necesaria para calcular ruta vial real. Si falta, el panel muestra los puntos y el precio pero sin inventar distancia ni trazado. |
| `TRIP_LOCATION_ENABLED` | opcional | Solo después de aplicar `backend/migrations/003_ubicacion_compartida.sql` de forma controlada. `'true'` habilita; cualquier otro valor o ausencia deja la función deshabilitada. |

### Reglas
- **No** añadir `MAPBOX_ACCESS_TOKEN`, `TEXTBEE_API_KEY`, `SMS_OTP_SECRET`,
  `FIREBASE_PRIVATE_KEY` ni `WOMPI_INTEGRITY_SECRET` en `NVM`, en el
  navegador, en Flutter ni en archivos del repositorio.
- Las variables de despliegue las gestiona el proyecto Vercel. Tras cambiarlas,
  vuelve a desplegar (`vercel --prod` o push al `main`) para que la API las
  tome.
- No ejecutar `db:migrate` contra `carmandb` ni volver a aplicar las
  migraciones `001_initial.sql` o `002_phone_verification.sql`. Para activar
  el seguimiento GPS, el flujo recomendado es:
  1. Crear en la base, mediante DBA, solo la tabla `ubicacion_compartida`
     definida en `backend/migrations/003_ubicacion_compartida.sql`.
  2. Confirmar que la tabla existe y está vacía.
  3. Añadir `TRIP_LOCATION_ENABLED=true` y volver a desplegar.
- Mientras `TRIP_LOCATION_ENABLED` no esté `'true'`, el resto funciona:
  bandeja de avisos, catálogo, reservas diarias y panel de ruta con puntos
  autorizados.
