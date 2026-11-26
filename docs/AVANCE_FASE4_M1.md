# Avance fase 4 — M1 cliente: cuenta, licencia, catálogo y favoritos

**Estado: M1 parcialmente implementado; no hay recorrido live certificado.**
Ver [PLAN_PANELES_POR_ROL.md](PLAN_PANELES_POR_ROL.md) y las dependencias
pendientes de [M0](AVANCE_FASE4_M0.md).

## Integración de este corte

- Recuperación: `POST /auth/password/solicitar-recuperacion` usa Firebase
  `PASSWORD_RESET` y responde igual si la cuenta no existe. Flutter solicita
  el enlace; en modo API no presenta una pantalla que cambie contraseñas sin
  código ni afirma que el cambio ya ocurrió. La entrega y los dominios
  autorizados del enlace todavía requieren un entorno de ensayo.
- Catálogo público: filtra por ciudad, marca/modelo, tipo de vehículo,
  tarifa **diaria**, capacidad y disponibilidad según reservas pendientes,
  confirmadas o en curso que se solapan. Ordena por identificador descendente
  o precio y pagina de 20 en 20 con `hayMas`; no devuelve placas, documentos
  ni datos privados. El frontend usa las mismas pantallas y widgets, muestra
  el error sin convertirlo en lista vacía, permite cargar más y oculta en
  live alquiler por horas y filtros sin fuente de datos (combustible,
  transmisión, apertura móvil, cancelación gratis, cercanía y rating).
  La búsqueda live ofrece las horas permitidas para la reserva.
- Licencia: el estado que devuelve el perfil distingue vigente, vencida
  y suspendida. El modo live **no** ofrece cargar fotos de licencia ni
  promete revisión biométrica, cifrado no comprobado o plazos inventados:
  el backend exige URL de documento y aún falta una carga segura.
- Favoritos: siguen separados por cuenta local y consultan el detalle
  **público** del vehículo; aún no se sincronizan entre dispositivos.
- La interfaz demo conserva sus controles y datos de prueba. No se añadieron
  dependencias ni se aplicaron migraciones.

## Verificación y límites

- `npm run build`: correcto; `npm test -- --runInBand`: 30 suites/134
  pruebas; `npm run test:e2e -- --runInBand`: 2 suites/7 pruebas con DB,
  Firebase y catálogo simulados, incluidas validaciones HTTP de recuperación
  y filtros. Los filtros y la respuesta de recuperación tienen pruebas de
  servicios con proveedores simulados.
- Flutter `test --no-pub`: 123 pruebas (demo y contratos con dobles HTTP);
  `build web --no-pub --dart-define=CARMAN_USE_LIVE_API=true`: correcto.
  `flutter analyze --no-pub`: **sin issues** al terminar los cambios de código.
- Sin base y cuentas de ensayo autorizadas no se comprobó un correo real,
  login/activación, cambio de cuenta live, permisos con terceros ni concurrencia
  entre catálogo y reserva. No se envió correo real ni se leyó/exportó
  información personal del entorno productivo.
- Falta una subida privada y validada de documentos, renovación segura del
  ID token y el ciclo de recuperación/activación con proveedor configurado.
  Por estas razones **no declarar M1 completo ni desplegarlo como tal**.
