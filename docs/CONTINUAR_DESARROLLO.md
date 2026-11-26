# Continuación de la integración `nuevaRama` — 26 de noviembre de 2026

Este archivo permite retomar el trabajo si se interrumpe la sesión. **No es una
certificación de funcionamiento integral ni una autorización para migrar datos.**

## Último despliegue

M6 favoritos se publicó en Production (`dpl_69RE9SpsRwSKkhQuJ8oG8eDCs9b6`)
después de que el usuario confirmara la creación de la tabla `favorito` en
TiDB. Smoke: web, salud y catálogo 200; ruta de favoritos sin token 401.
No se ejecutó ninguna migración ni escritura de ensayo en `carmandb`
desde este proyecto. Falta probar permisos SQL y recorridos autenticados
con cuentas de ensayo. Ver
[AVANCE_FASE4_M6_FAVORITOS.md](AVANCE_FASE4_M6_FAVORITOS.md).

El ajuste posterior para no descargar fotografías de `example.com` está
publicado en Production como `dpl_5DkwW2uzJ4ZEoC3ncBPvxfciw45C`
(`boris`: `10d2ab3`). Web, salud y catálogo respondieron HTTP 200.
El corte M6 todavía no estaba desplegado cuando se hizo esta verificación
anterior; su migración `004` se había aplicado solo a `carman_ensayo`.

Por autorización explícita se publicó el corte local en Production
(`dpl_85wj6E7PaFpnzL124qFpUyvkr6Ny`), sin migrar `carmandb`.
Smoke: web, salud y catálogo HTTP 200; cinco rutas privadas sin token 401.
M0–M5 **siguen parciales**, sin certificación de pagos, documentos ni
recorridos con cuentas reales. Evidencia:
[VERIFICACION_VERCEL_2026_11_26.md](VERIFICACION_VERCEL_2026_11_26.md).
Las referencias «todavía local/no desplegado» más abajo describen los
cortes anteriores y no el estado de esta publicación.

## Ensayo aislado posterior

Se preparó MySQL local `carman_ensayo` (sin usar `carmandb`), se completó
el esquema faltante en la migración `002_z_complete_baseline.sql` y se
dejaron 20 tablas de negocio accesibles. La migración optativa de GPS se
omite por defecto. Seis pruebas HTTP contra SQL **real** pasaron con
filas ficticias y verificador Firebase simulado: roles, 401/403,
catálogo y solapes, titularidad de vehículo, licencia obligatoria,
reservas concurrentes, transiciones de cuenta, carrera de dos
administradores y persistencia de informe. Instrucciones
y límites en [ENSAYO_AISLADO.md](ENSAYO_AISLADO.md).
Esto **no cierra M0–M5**: faltan identidades de ensayo en Firebase, carga
documental segura, pago Sandbox real y los recorridos restantes. No
promover una versión integral basándose solo en esas pruebas.
La inspección sin divulgar valores de `backend/.env` confirmó que apunta
a `carmandb`; su proyecto Firebase no está identificado como ensayo y
las claves Wompi **antes** no cumplían el validador. Tras modificar el
archivo, las seis variables **ya pasan la comprobación local de formato
Sandbox** de `WompiService`. Una consulta **GET de solo lectura** al
merchant de Wompi Sandbox reconoció la clave pública (HTTP 200); no
confirma la clave privada, los secretos de firmas ni los valores ocultos
de Vercel. No se reutilizó para crear usuarios ni
realizar cobros. En Vercel Preview
faltaban variables de DB y Firebase que sí existían en Production;
no copiar secretos de Production a Preview como atajo.
El ensayo de despliegue y sus HTTP observados están en
[VERIFICACION_VERCEL_2026_11_26.md](VERIFICACION_VERCEL_2026_11_26.md).

## Auditoría posterior y próximo alcance elegido

**Actualización posterior:** se inició la fase 4 por solicitud del usuario.
Ver [`AVANCE_FASE4_M0.md`](AVANCE_FASE4_M0.md) para los cambios efectuados
y los criterios de M0 aún pendientes. Las viñetas siguientes registran
el estado histórico al terminar la auditoría, antes de implementar.
En el corte más reciente: 30 suites/130 tests backend y 118 tests Flutter
pasaron; las acciones del repositorio de conductor ya usan rutas reales,
pero su resumen live continúa sin endpoint y M0 sigue sin validación con
cuentas/base de ensayo.
**Corte posterior de M1:** se inició cuenta, licencia y catálogo; ver
[`AVANCE_FASE4_M1.md`](AVANCE_FASE4_M1.md). Las cifras históricas anteriores
no describen las pruebas de este corte. M0 continúa abierto.
Última regresión de M1: build backend, 30 suites/134 pruebas unitarias,
2 suites/7 pruebas HTTP simuladas, build Flutter web live y 123 pruebas
Flutter correctas; `flutter analyze --no-pub` final sin issues.
**Corte siguiente de M2 (parcial):** detalle autenticado de reserva, estado
de orden/saldo, opción de conductor y pagos únicamente en Sandbox con
consulta explícita posterior al checkout. Ver
[`AVANCE_FASE4_M2.md`](AVANCE_FASE4_M2.md); M0 y M1 no se consideran cerrados.
**M3 propietario (parcial, todavía local):** inventario propio, detalle privado,
edición de tarifa/descripción, pausa/reactivación y solicitud de revisión
conectados a rutas reales y recarga de estado; el alta live continúa bloqueada
por la ausencia de carga documental segura. Ver
[`AVANCE_FASE4_M3.md`](AVANCE_FASE4_M3.md). No desplegar este corte por
implicación del despliegue previo de M2.
**M4 conductor (parcial, todavía local):** reservas asignadas paginadas,
disponibilidad, aceptar/rechazar e iniciar/finalizar conectados a rutas reales,
con comprobación de licencia, estado y recarga. El historial de asignaciones
rechazadas y las liquidaciones siguen pendientes. Ver
[`AVANCE_FASE4_M4.md`](AVANCE_FASE4_M4.md). No desplegado.
**M5 administración (parcial, todavía local):** resumen real limitado,
usuarios y revisiones paginados, detalle privado, suspensión/reactivación
y transiciones técnicas protegidas. Sin ensayos multicuenta reales;
ver [`AVANCE_FASE4_M5.md`](AVANCE_FASE4_M5.md). No desplegado.

El 26 de noviembre se realizó una auditoría adicional, limitada por solicitud
del usuario a exploración, pruebas y plan (fases 1–3). La guía actual para
decidir cuándo implementar es
[`PLAN_PANELES_POR_ROL.md`](PLAN_PANELES_POR_ROL.md); la evidencia está en
[`AUDITORIA_HTTP_2026_11_26.md`](AUDITORIA_HTTP_2026_11_26.md).

- Se reprodujo HTTP 500 al registrar sin objeto `persona` y un defecto de
  doble lectura de la respuesta de Firebase en el servicio de correo.
- El backend temporal arrancó con DB real: 69 casos HTTP, 68 con estado
  esperado y un fallo; 42 rutas protegidas rechazaron peticiones sin token.
  No se certificó éxito privado ni se hicieron mutaciones autenticadas.
- Se repitieron build/107 pruebas backend, 5 tests HTTP con dependencias
  simuladas, Flutter analyze y 109 tests. No hubo despliegue ni correcciones.
- Metadatos locales confirman ambos UNIQUE de calificaciones; no se
  encontraron CHECK de esa tabla en el catálogo consultado ni la tabla
  optativa de GPS. No se ejecutó una migración.
- La fase 4 queda **pendiente de elección**. Empezar por M0 del plan cuando
  se solicite. Las secciones siguientes conservan el historial anterior.

## Estado y conservación

- Rama local `boris`, base de integración con `origin/nuevaRama` (`9b5a99b`).
  Se trasladaron **selectivamente** sus rutas de calificación e historial:
  `backend/src/calificaciones/`, `backend/src/pagos/pagos.controller.ts` y
  `backend/src/pagos/pagos.service.ts`. No se hizo merge ni push de la rama.
- El checkout ya tenía muchas modificaciones ajenas a esta integración,
  además de archivos no seguidos en `docs/entrega/`, GPS, rutas y Flutter.
  **No hacer `git reset`, `checkout --`, `clean` ni sobrescribir archivos
  originales** para completar la integración; revisar `git status --short`.
- Se preservó `docs/carman_tables.txt`: `nuevaRama` lo elimina, pero contiene
  un DDL **documental** importante; no es la fuente certificada de la DB viva.
- No incluir `.env*`, evidencias privadas, exportaciones de filas, teléfonos,
  tokens, contraseñas, coordenadas personales ni claves en un despliegue o
  documento. **No ejecutar `db:migrate` ni el DDL anexo sobre `carmandb`**.
  `backend/migrations/003_ubicacion_compartida.sql` es optativa: no aplicarla
  ni habilitar GPS hasta tener autorización y verificar políticas de retención.

## Integración local hecha

- `POST /calificaciones/reservas/:idReserva`: sesión cliente, reserva propia
  finalizada, vehículo o conductor asignado; duplicado controlado por la
  restricción `UNIQUE` documentada. Consultas públicas de valoraciones por
  vehículo/conductor: puntuaciones y total, sin nombres, comentarios libres
  ni IDs de reservas.
- `GET /pagos/historial`: sesión del cliente, hasta 100 movimientos de
  **sus reservas**, importe y estado; sin placa, nombres de terceros, PDF de
  orden, referencias de pasarela ni información de tarjeta.
- Flutter: envío de la reseña del vehículo con contrato nuevo, indicador de
  reseña enviada, promedio de reseñas al abrir detalle, historial de pagos de
  solo lectura en perfil live. La pantalla demo de tarjetas no admite entrada
  en modo API y una nota sin reseñas reales no se presenta como puntuación.
- No se añadió un método de cobro real ni interfaz de reseña del conductor.
  El panel live de conductor sigue usando rutas `GET /conductor/resumen` y
  `PATCH /conductor/servicios/*` inexistentes en esta API. El panel de admin
  todavía llama rutas/respuestas no equivalentes a `GET /admin/revisiones`
  y `PATCH /admin/usuarios/:id/suspender|reactivar`. El panel propietario
  muestra cifras demo/no acreditadas. **No prometer que esos recorridos
  funcionan ni lanzar producción bajo la premisa de cobertura completa.**

## Validación ejecutada en este punto

- Backend: `npm ci --no-audit --no-fund`, `npm run build`,
  `npm test -- --runInBand`: **26 suites / 107 tests superados**.
  `npm ci` emitió avisos de motor para Node 24.13.1; revisar versión requerida
  antes de un build Linux reproducible.
- Flutter Windows (en WSL el lanzador Linux `/mnt/c/flutter` tiene CRLF):
  `cmd.exe /c C:\\flutter\\bin\\flutter.bat analyze --no-pub` sin issues;
  `cmd.exe /c C:\\flutter\\bin\\flutter.bat test --no-pub`: **109 tests
  superados**. Build: `cmd.exe /c C:\\flutter\\bin\\flutter.bat build web
  --release --no-pub --dart-define=CARMAN_USE_LIVE_API=true` superado.
- Son unit tests, tests de widgets/dobles HTTP y compilación de Windows:
  **no son comprobación E2E de una cuenta, tabla de calificaciones, Wompi,
  Firebase ni del proceso de build Linux de Vercel**. La última verificación
  del servicio de correo en producción falló anteriormente.

## Pasos antes de desplegar

1. Confirmar que el árbol local corresponde al que se desea publicar y que
   `.vercelignore` excluye credenciales/evidencias; no enviar el checkout
   completo por inercia. Inspeccionar `git diff --stat` y `git status --short`.
2. Adaptar realmente los paneles conductor/administrador/propietario a los
   endpoints de `backend/src/*/*.controller.ts` o dejarlos explícitamente
   deshabilitados en live. Añadir pruebas por rol y de rutas 401/403/404;
   diferenciar valores faltantes de estadísticas reales en las pantallas.
3. Verificar **solo con permiso, entorno y cuentas de prueba apropiados**
   el esquema de calificación y la autorización de reservas/historial, sin
   exportar filas personales ni crear cargos. Confirmar si en `calificacion`
   existen los índices únicos y la restricción XOR documentados antes de
   permitir calificar; el endpoint depende de ellos para evitar duplicados.
4. Repetir backend build/tests y Flutter analyze/tests/build, más pruebas
   de despliegue en Vercel (Linux), y actualizar el manual con *resultados
   observados*; no extrapolar HTTP 200/401 públicos a operaciones privadas.
5. Solo después, decidir si corresponde publicar una **única** versión
   final con `vercel --prod`; comprobar `/api/health`, catálogo y rechazo
   sin token, y registrar fecha/URL. **A esta fecha no se hizo un nuevo
   deploy de esta integración.** Si una comprobación falla, no lanzar
   producción ni afirmar que quedó desplegada.

## Documentación y entrega

- Las fuentes editables están en `docs/entrega/*.md` y este archivo.
- La exportación anterior `docs/entrega/DOCX_SIN_CAMPOS/` y su ZIP se conservan
  para otros integrantes (pueden estar abiertos). Al regenerar DOCX por la
  integración, **usar una carpeta nueva** y ejecutar el validador sobre ella;
  revisar visualmente en Word, pues los índices son de texto fijo.
- Registrar explícitamente cuándo se hizo la última prueba/despliegue y
  cuáles recorridos están pendientes. No incorporar capturas o datos reales
  de cuentas a los entregables.
