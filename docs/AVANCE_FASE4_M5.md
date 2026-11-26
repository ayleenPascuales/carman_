# Avance fase 4 — M5 administración: cuentas y revisiones

**Estado: parcial; publicado posteriormente sin certificación integral.** El alcance y aceptación están en
[PLAN_PANELES_POR_ROL.md](PLAN_PANELES_POR_ROL.md). M0–M4 también conservan
pendientes propios.

## Este corte

- `GET /admin/resumen` deriva de conteos reales de usuarios, conductores
  disponibles con licencia vigente, vehículos activos, revisiones pendientes
  y reservas creadas hoy; no presume ingresos ni crecimiento. Listados
  `GET /admin/usuarios` y `GET /admin/revisiones` filtran y paginan de 20
  en 20 con parámetros acotados. La lista de usuarios no incluye documentos
  ni teléfonos; el detalle solo se solicita explícitamente con sesión admin.
  Las revisiones `Pendiente` y `Aprobada` se listan por separado para poder
  completar inspecciones aprobadas. El detalle individual se consulta por ID.
- El panel Flutter conserva Resumen/Usuarios/cards; en modo API la tercera
  pestaña indica **Revisiones** y no mezcla licencias con inspecciones.
  Búsqueda y filtros de rol/estado consultan al backend; «cargar más» añade
  páginas sin fingir un total de resultados en pantalla. Las rutas privadas
  `/admin/users/:id` y `/admin/revisions/:id` consultan detalle con token.
  Rechazar exige motivo; finalizar requiere nombre/documento del técnico y
  observaciones. No se muestran viajes o ingresos inexistentes como métricas.
- Suspender y reactivar se ejecutan dentro de transacción y bloqueo de la
  persona; no permite suspender la propia cuenta ni otra cuenta administrativa
  activa. Solo se suspende `Activo` y se reactiva `Suspendido`. Aprobar y
  rechazar requieren la transición atómica desde `Pendiente`/
  `revision_pendiente`; la carrera con otro administrador devuelve error.
  Rechazar deja el vehículo **inactivo** para que el propietario decida si
  reactiva su publicación, en vez de publicarlo automáticamente.
- Finalizar mantiene el bloqueo transaccional existente de
  `En_mantenimiento`/`Aprobada`, exige datos técnicos y evita marcar `Activo`
  si requiere mantenimiento. No se concede ningún rol ni se declara aprobada
  una licencia mediante estas rutas.

## Límites y verificación

- Sin cuentas autorizadas y base de ensayo aislada no se ensayó el recorrido
  real con dos administradores, permiso 403 ni informes técnicos persistidos;
  las regresiones eran con dobles. **Actualización:** en
  [ENSAYO_AISLADO.md](ENSAYO_AISLADO.md) constan seis pruebas HTTP con
  MySQL local aislado y dos administradores ficticios; solo el verificador
  Firebase está simulado. Aún falta verificar identidades Firebase reales
  y el flujo desde Flutter. No cambiar `carmandb` ni exportar datos
  personales. La paginación por desplazamiento puede moverse ante cambios
  concurrentes: falta cursor/historial de decisiones y política explícita
  para publicaciones tras inspección. Por eso M5 sigue **parcial**.
- Build backend, 31 suites/155 pruebas de backend y 2 suites/11 pruebas HTTP
  simuladas correctas. Flutter: 131 pruebas demo (6 pruebas live omitidas en
  modo demo), 3 pruebas M5 live con dobles. Build web live correcto.
  `flutter analyze --no-pub` final sin issues.
