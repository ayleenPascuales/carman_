# Avance fase 4 — M3 propietario: inventario y revisión

**Estado: parcial; no es un recorrido de publicación live completo.**
Ver [PLAN_PANELES_POR_ROL.md](PLAN_PANELES_POR_ROL.md) y las dependencias
de [M0](AVANCE_FASE4_M0.md) y [M1](AVANCE_FASE4_M1.md).

## Este corte

- El panel live obtiene `/vehiculos/mis-vehiculos` autenticado, sin llamar
  al resumen `/propietario/resumen` que no existe. Cuenta vehículos y activos
  reales, distingue `Activo`, `inactivo` y `revision_pendiente`, muestra
  errores de consulta en vez de convertirlos en inventario vacío y elimina
  ingresos, comisiones, ocupación y mantenimiento futuro sin fuente.
- Las reservas del panel se filtran por IDs del inventario propio; un
  fallo de carga se muestra como fallo, no como «no hay reservas». El detalle
  privado `/owner/vehicles/:id` usa `GET /vehiculos/:id` con token y muestra
  placa, tarifa y estado de revisión al titular. `/edit` modifica solo
  tarifa diaria y descripción mediante PATCH; `/revision` envía motivo a
  POST y vuelve a consultar el servidor. Pausar/reactivar usa PATCH con
  `Activo`/`inactivo` exactos, sin cambio optimista del estado live.
- El backend bloquea la solicitud de revisión en una transacción con
  comprobación de titularidad y reservas activas; así evita que el cambio
  compita con pausas y nuevas reservas. La revisión deja el vehículo
  fuera del catálogo y **no** supone aprobación técnica.
- El alta de propietario/primer vehículo **no** se simula: requiere fotos y
  tarjeta de propiedad, pero no existe aún el endpoint de carga privada
  validada. En modo API el widget existente muestra esta limitación y no
  envía assets demo, rutas `local://` ni enlaces externos inventados.
  El perfil lleva a esa pantalla informativa sin intentar dar de alta un
  rol propietario mediante la ruta de conductor.
- El modo demo conserva sus widgets y comportamiento. En el corte inicial
  M3 no se había desplegado; después se publicó por autorización expresa
  sin certificar el recorrido de alta documental.

## Verificación y límites

- Build NestJS, 30 suites/142 pruebas backend y 2 suites/9 pruebas HTTP
  simuladas correctas. Sin consultas ni escrituras de negocio reales en
  estas pruebas.
- 131 pruebas Flutter correctas (demo y contratos HTTP con dobles). Build web con
  `CARMAN_USE_LIVE_API=true` correcto; `flutter analyze --no-pub` final
  **sin issues**.
- Sin cuentas y base **de ensayo aislada**, no se ensayaron publicar/editar/
  pausar/reactivar/revisar con permisos multicuenta ni carreras reales.
  Falta carga segura de documentos y fotos, detalle/historial técnico
  completos, y un resumen propio si se quiere mostrar métricas financieras.
  No ejecutar migraciones en `carmandb` ni declarar M3 completo.
