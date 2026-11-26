# CARMAN — Auditoría y plan de integración por rol

**Corte de auditoría: 26 de noviembre de 2026.** Este texto conserva el plan
previo a los cambios. La fase 4 comenzó después, con avances de M0 registrados
en [`AVANCE_FASE4_M0.md`](AVANCE_FASE4_M0.md); **M0 todavía no está completo**.

## 0. Conclusión y alcance acordado

El proyecto tiene una base reutilizable de NestJS y Flutter, pero **todavía
no permite recorridos completos por los cuatro roles**. Hay 56 rutas
backend en 14 controladores, 15 servicios, y 30 pantallas Flutter dentro de
106 archivos Dart. El inventario incluye los cambios locales del checkout
`boris` / `32bf073`.

Se completaron la exploración, revisión de contratos/permisos, pruebas
HTTP acotadas y mapeo frontend de las fases 1–3 solicitadas. La corrección
preventiva del punto 4 de la fase 1 se reserva para el inicio de la
**fase 4 de ejecución**, por la instrucción de detenerse antes de corregir
o implementar.

**Resultados actuales:** build backend correcto; 107 tests backend y 5
tests HTTP con dependencias simuladas correctos; Flutter analyze sin issues
y 109 tests correctos. En el servidor real: 69 casos HTTP, un 500 inesperado
en registro. El correo tiene otro defecto reproducido con un proveedor
simulado de respuesta nativa. Ver el alcance y las pruebas exactas en
[`AUDITORIA_HTTP_2026_11_26.md`](AUDITORIA_HTTP_2026_11_26.md).

El orden propuesto de ejecución es: correcciones comunes → cliente →
propietario → conductor → administración. Las dependencias backend que
necesita el cliente se resuelven primero, aunque pertenezcan a otro rol.

## 1. Fase 1 — Backend, base de datos y permisos

### 1.1 Estructura y arquitectura

| Ubicación | Función comprobada |
|---|---|
| `backend/src/main.ts`, `configure-app.ts`, `app.module.ts` | Arranque Nest, CORS, `ValidationPipe`, módulos y cron |
| `backend/src/auth/` | Firebase Admin/REST, guard, verificación correo/SMS y mantenimiento |
| `backend/src/personas/` | Registro, perfil, licencia, alta de conductor, disponibilidad |
| `backend/src/vehiculos/`, `puntos/` | Publicación, catálogo, inventario propio, puntos públicos |
| `backend/src/reservas/` | Crear/editar/cancelar, asignar conductor, responder, consulta por participantes |
| `backend/src/pagos/`, `archivos/` | Orden/PDF, checkout Wompi Sandbox, webhook, historial propio |
| `backend/src/calificaciones/`, `notificaciones/` | Reseñas y avisos por destinatario |
| `backend/src/admin/` | Usuarios y revisión técnica de vehículos |
| `backend/src/rutas/` | Cercanía, ruta prevista Mapbox, ubicación compartida opcional |
| `backend/src/database/` | SQL directo con `mysql2/promise`, pool TLS; **sin ORM** |
| `backend/migrations/`, `scripts/migrate.cjs` | DDL inicial parcial y migraciones; no son una reproducción completa del esquema actual |
| `frontend/lib/` | Flutter, capas `core`, `data`, `features`, `shared`, composición en `providers.dart` |
| `frontend/test/`, `backend/src/**/*.spec.ts`, `backend/test/` | Tests existentes; buena parte usa mocks/demo |
| `docs/carman_tables.txt` | DDL documental de 20 tablas, conservado |
| `vercel.json` | Servicios web/API, rewrite `/api`, schedule de cuentas inactivas |
| `frontend/scripts/build-web.sh` | SDK Flutter Linux fijado y verificado por checksum; build API |
| `infrastructure/readme.md` | Documentación; no sustituye configuración ejecutable de infraestructura |

El prefijo `/api` solo se activa con `VERCEL`; por defecto local las rutas
no lo llevan. Los paths de inventario siguientes son **sin prefijo**.

Dependencias funcionales: Personas → Auth/Verification, Reservas y
Notificaciones; Reservas → Pagos y Notificaciones; Pagos → Wompi, Archivos
y Notificaciones; Notificaciones → Verification; Admin → DB;
Rutas/Ubicación → DB/configuración. Conservar inyección y módulos existentes.

### 1.2 Configuración revisada

Se revisaron las claves de los archivos de entorno y los ejemplos, sin
copiar sus valores privados.

| Grupo | Variables y comportamiento |
|---|---|
| DB | `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_POOL_SIZE`, `DB_SSL_CA` o `DB_SSL_CA_PATH`; TLS verificado, zona de conexión `-05:00` |
| Firebase | `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`; credencial por JSON, email/private key o `GOOGLE_APPLICATION_CREDENTIALS` |
| Activación | `TEXTBEE_API_KEY`, `SMS_OTP_SECRET` de 32 bytes hex; correo antes de SMS, código 6 dígitos, 10 minutos, límites de intentos/reenvíos |
| Pagos | `WOMPI_BASE_URL`, `WOMPI_PUBLIC_KEY`, `WOMPI_PRIVATE_KEY`, `WOMPI_INTEGRITY_SECRET`, `WOMPI_EVENTS_SECRET`, `WOMPI_CHECKOUT_URL`; validación estricta **Sandbox** |
| Rutas/GPS | `MAPBOX_ACCESS_TOKEN`, `TRIP_LOCATION_ENABLED`; sin Mapbox devuelve ruta no calculada, sin flag no admite compartir GPS |
| HTTP/cron | `PORT`, `CORS_ORIGINS`, `VERCEL`, `NODE_ENV`, `CRON_SECRET` |
| Flutter | `CARMAN_USE_LIVE_API` es `false` por defecto; `CARMAN_API_URL`; web por defecto usa origen actual + `/api` |

El ejemplo backend no documenta todos los grupos opcionales actuales de
Wompi/Mapbox/GPS. Incluirlos sin secretos al ejecutar la fase 4.
`validate-env.ts` valida requisitos base; que el arranque pase no acredita
la entrega de correo/SMS ni pagos.

### 1.3 Modelo de autorización

- `AuthGuard` verifica el ID token con revocación en Firebase y resuelve
  **`idPersona` por `uidFirebase`**, no por un ID enviado en el body.
- Rechaza personas suspendidas; puede actualizar inactividad, última
  actividad y correo verificado. Incluso un GET autenticado puede escribir
  esos datos de cuenta.
- Si el claim `requiresVerification` es `true`, exige correo y teléfono
  activados. Las cuentas históricas sin ese claim siguen la excepción
  implementada; no afirmar que todas pasan doble verificación.
- `AllowUnverified`: estado de verificación, reenvíos/confirmación y
  **GET** perfil. No permite saltarse token ni suspensión.
- `AdminGuard` consulta `administrador` por `idPersona` con `estado='Activo'`.
  No existe un guard genérico de los otros roles: la mayoría se resuelve en
  servicios y condiciones SQL.
- Roles múltiples: `cliente`, `propietario`, `conductor`, `administrador`
  tienen un `idPersona` único por tabla. No confundir `idPersona`,
  `idCliente`, `idPropietario` e `idConductor`.
- Crear reserva puede crear automáticamente `cliente`; publicar vehículo
  puede crear `propietario`. `POST /personas/roles` **solo agrega conductor**.
  No admite un campo `roles` ni alta de administrador.

### 1.4 Inventario de las 56 rutas

**Leyenda de estado:**

- **Funcional limitado**: se verificó el caso HTTP descrito; no se extrapola.
- **Por verificar**: existe, pero falta probar el éxito privado/con datos.
- **Requiere corrección**: defecto encontrado; todavía no corregido.
- **Faltante**: no existe; se lista en 1.5.
- **Corregido: ninguno en esta auditoría.**

Se amplían las tres etiquetas solicitadas para evitar llamar «Funcional» a
una operación que solo devolvió 401.

Permisos: **P** público; **V** sesión válida con política de verificación
anterior; **U** sesión con `AllowUnverified`; **A** V + administrador activo.
**42 rutas V/U/A devolvieron 401 sin token.** Eso acredita el guard, no
titularidad/roles con una sesión válida.

#### Infraestructura y autenticación

| Método / ruta | Permiso | Respuesta / consumidor | Estado y evidencia |
|---|---|---|---|
| `GET /` | P | Texto de `AppService` | Funcional limitado: 200 |
| `GET /health` | P | `{status,database}` | Funcional limitado: 200 y consulta DB |
| `GET /health/tablas` | P | `{tablas,total}` | Funcional limitado: 20 nombres detectados; no verifica todo el DDL |
| `GET /internal/inactive-accounts` | Secreto cron | `{status}`; Vercel Schedule | Por verificar ejecución: 403 sin secreto |
| `POST /auth/login` | P | `{uid,idToken,refreshToken,expiresIn}`; login Flutter | Por verificar éxito: 400 vacío, 401 sintético |
| `GET /auth/verificacion` | U | `{requiereVerificacion,correoVerificado,telefonoVerificado,activada}`; login/OTP | Por verificar: 401 |
| `POST /auth/correo/reenviar` | U | `{mensaje}`; OTP | **Requiere corrección**: doble lectura de respuesta |
| `POST /auth/telefono/reenviar` | U | `{mensaje}`; OTP | Por verificar SMS real: 401 |
| `POST /auth/telefono/confirmar` | U | Estado de verificación; OTP | Por verificar código real: 401 |
| `GET /auth/admin/prueba` | A | `{mensaje,idPersona,rol}`; diagnóstico sin pantalla | Por verificar rol válido: 401 |

Fuentes: `backend/src/auth/auth.controller.ts:27`,
`auth.guard.ts:18`, `auth.service.ts:50`,
`maintenance.controller.ts:15`, `health/health.controller.ts:18`.

#### Personas y licencias

| Método / ruta | Permiso efectivo | Respuesta / consumidor | Estado |
|---|---|---|---|
| `POST /personas/registro` | P; validación y creación Firebase/DB | `{mensaje,idPersona,rol,correoEnviado,correoDetalle,smsEnviado}`; registro parcial | **Requiere corrección**: sin `persona` da 500, correo defectuoso |
| `POST /personas/roles` | V; propia persona, licencia vigente, conductor no existente | `{mensaje,idPersona,idConductor,rol}`; alta conductor con body Flutter incorrecto | Por verificar: 401; integración incompatible |
| `POST /personas/licencia` | V; licencia propia única | `{mensaje,idPersona,idLicencia}`; sin envío live desde UI | Por verificar: 401 |
| `PUT /personas/licencia` | V; propia, no suspendida | Mismas claves; renovación sin UI live | Por verificar: 401 |
| `GET /personas/perfil` | U; propia | Campos de perfil + `licenciaEstado`, `roles` booleanos; login/perfil | Por verificar éxito: 401 y token inválido 401 |
| `PATCH /personas/perfil` | V; propia | `{mensaje,idPersona}`; editar perfil | Por verificar: 401; cambio de teléfono requiere resolver reverificación |
| `PATCH /personas/conductor/disponibilidad` | V; conductor propio y licencia si activa | `{mensaje,idPersona,disponibilidad,reservasAsignadas}` | Por verificar: 401; panel llama otro path/body |

Fuente: `backend/src/personas/personas.controller.ts:18`.

#### Vehículos y puntos

| Método / ruta | Permiso efectivo | Respuesta / consumidor | Estado |
|---|---|---|---|
| `POST /vehiculos` | V; crea propietario propio si falta, puntos activos | `{mensaje,idVehiculo}`; repositorio preparado, formulario incompleto | Por verificar escritura: 401 |
| `GET /vehiculos/mis-vehiculos` | V; `propietario.idPersona` | Array; fallback del panel propietario | Por verificar: 401 |
| `GET /vehiculos/catalogo` | P; activos, tarifa positiva, punto activo | `{vehiculos}`; home/resultados/mapa | Funcional limitado: 200 vacío y ciudad inválida 400 |
| `GET /vehiculos/catalogo/:idVehiculo` | P; mismo filtro | Objeto público, sin placa/documentos del dueño | Por verificar dato existente: 400/404 observados |
| `GET /vehiculos/:idVehiculo` | V; propietario del vehículo por JOIN | Objeto privado; publicación y **favoritos lo usa incorrectamente** | Por verificar: 401 |
| `PATCH /vehiculos/:idVehiculo` | V; propietario | `{mensaje}`; sin editor UI | Por verificar: 401 |
| `PATCH /vehiculos/:idVehiculo/estado` | V; propietario | `{mensaje,estado}`; UI no lo invoca | **Requiere corrección** de transiciones; 401 observado |
| `POST /vehiculos/:idVehiculo/solicitar-revision` | V; propietario, restricciones de solicitud/6 meses | `{mensaje,estado}`; sin UI | Por verificar: 401 |
| `GET /puntos-autorizados` | P; solo activos, ciudad opcional | Array; búsqueda/recogida | Funcional limitado: 200, ciudad inválida 400 |

Fuentes: `vehiculos/vehiculos.controller.ts:13`,
`vehiculos.service.ts:118,156,191,258`, `puntos/puntos.controller.ts:8`.

#### Reservas, calificaciones y pagos

| Método / ruta | Permiso efectivo | Respuesta / consumidor | Estado |
|---|---|---|---|
| `POST /reservas/vehiculo/:idVehiculo` | V; crea cliente propio si falta | `{mensaje,idReserva,estado,requiereDecisionConductor}`; checkout sin conductor | **Requiere corrección** de concurrencia/reglas; 401 observado |
| `GET /reservas/mis-reservas` | V; cliente **o** dueño **o** conductor de la reserva | `{mensaje,total,reservas}`; viajes/propietario | Por verificar: 401; no es lista exclusivamente cliente |
| `PATCH /reservas/:idReserva` | V; cliente titular, Pendiente/Confirmada y pagos compatibles | Fechas, estados, precio, `pdfActualizado`; sin editor UI | **Requiere corrección** de fechas parciales/concurrencia; 401 |
| `PATCH /reservas/:idReserva/cancelar` | V; cliente titular, estado/pagos compatibles | `{mensaje,idReserva,estado}`; detalle viaje | Por verificar: 401 |
| `PATCH /reservas/:idReserva/respuesta-conductor` | V; conductor asignado, pendiente de respuesta | Estado, asignación/precio o lista interna de rechazados | **Requiere corrección**: aceptar no confirma reserva; 401 |
| `POST /calificaciones/reservas/:idReserva` | V; cliente titular, Finalizada, objetivo existente | `{mensaje,idCalificacion,idReserva,tipoObjetivo,puntuacion}`; UI solo vehículo | Por verificar escritura: 401; únicos confirmados por metadatos |
| `GET /calificaciones/vehiculo/:idVehiculo` | P; existencia del vehículo | `{idVehiculo,promedio,totalCalificaciones,calificaciones}`; detalle vehículo | Por verificar resultado con datos: 400/404 |
| `GET /calificaciones/conductores/:idConductor` | P; existencia conductor | Mismo resumen con `idConductor`; sin consumidor | Por verificar resultado con datos: 400/404 |
| `POST /pagos/reservas/:idReserva/orden` | V; cliente titular, Confirmada | `{mensaje,ordenPago}` con ID/total/estado/ruta PDF; sin UI | Por verificar: 401 |
| `POST /pagos/ordenes/:idOrdenPago/checkout` | V; cliente titular, orden Activa, ventana temporal/pagos válidos | `{mensaje,pago,checkoutUrl}`; sin UI | Por verificar Sandbox: 401 |
| `POST /pagos/wompi/eventos` | Firma y entorno Sandbox; sin AuthGuard | `{mensaje,estado?,estadoOrden?,requiereRevision?}` | Funcional limitado: firma ausente 400; éxito pendiente |
| `GET /pagos/historial` | V; pagos de reservas del cliente titular | `{mensaje,totalMostrados,pagos}`, límite 100; pantalla historial | Por verificar: 401 |
| `GET /archivos/:idDocumento` | V; orden de pago del cliente titular | PDF binario, `private,no-store`; sin lector UI | Por verificar: 401 |

Fuentes: `reservas/reservas.controller.ts:12`,
`reservas.service.ts:22,196,528,632,888`,
`calificaciones/calificaciones.controller.ts:10`,
`pagos/pagos.controller.ts:19`, `archivos/archivos.service.ts:56`.

#### Rutas y notificaciones

| Método / ruta | Permiso efectivo | Respuesta / consumidor | Estado |
|---|---|---|---|
| `GET /rutas/vehiculos/:idVehiculo/punto-cercano` | P; vehículo/punto activo | `{punto,distanciaAproximadaKm,criterio}`; checkout | Por verificar caso válido: ID 0 → 400 |
| `POST /rutas/vehiculos/:idVehiculo/punto-cercano` | P; coordenadas válidas; no persiste posición | Mismas claves; cercanía voluntaria | Por verificar caso válido: fuera de rango → 400 |
| `GET /rutas/reservas/:idReserva` | V; cliente, dueño o conductor participante | Origen/destino, tarifa, distancia/duración/trayectoria/proveedor; viaje | Por verificar Mapbox/participación: 401 |
| `GET /rutas/reservas/:idReserva/ubicacion` | V; cliente/conductor adultos; no dueño por ese rol | `{disponible,compartiendo,posiciones}`; viaje activo | Por verificar: 401; tabla optativa ausente |
| `POST /rutas/reservas/:idReserva/ubicacion` | V; anteriores + EnCurso + flag + consentimiento | `{compartiendo,caducaEnSegundos}` | Por verificar: 401; capacidad no habilitada |
| `DELETE /rutas/reservas/:idReserva/ubicacion` | V; borra **solo** la fila del solicitante, incluso si ya no participa | `{compartiendo:false}` | Por verificar borrado: 401 |
| `GET /notificaciones` | V; destinatario propio | `{notificaciones}`, límite 100; lista/badge | Por verificar: 401 |
| `PATCH /notificaciones/leidas` | V; destinatario propio | `{mensaje}`; marcar todas | Por verificar: 401 |
| `PATCH /notificaciones/:id/leida` | V; destinatario propio por WHERE | `{mensaje}`; marcar una | Por verificar: 401 |

Fuentes: `rutas/rutas.controller.ts:12`, `rutas.service.ts:75`,
`ubicacion.service.ts:21`, `notificaciones/notificaciones.controller.ts:10`.

#### Administración

Todas usan AuthGuard + AdminGuard en el controlador.

| Método / ruta | Respuesta / operación | Estado |
|---|---|---|
| `GET /admin/usuarios` | `{mensaje,total,usuarios}`; filtros `rol`, `buscar`; sin paginación | Por verificar: 401; UI lee la lista mediante fallback |
| `GET /admin/usuarios/:idPersona` | Perfil detallado con `roles`; sin pantalla conectada | Por verificar: 401 |
| `PATCH /admin/usuarios/:idPersona/suspender` | `{mensaje}`; cambia `persona.estado` | Por verificar: 401; panel usa path distinto |
| `PATCH /admin/usuarios/:idPersona/reactivar` | `{mensaje}`; estado/última actividad | Por verificar: 401; panel usa path distinto |
| `GET /admin/revisiones` | `{mensaje,total,solicitudes}`; **solo Pendiente** | Por verificar: 401; sin consumidor equivalente |
| `PATCH /admin/revisiones/:idVehiculo/aceptar` | `{mensaje,estado,estadoSolicitud}`; mantenimiento/Aprobada | Por verificar: 401 |
| `PATCH /admin/revisiones/:idVehiculo/rechazar` | Lo anterior + `motivoRechazo`; Activo/Rechazada | Por verificar: 401 |
| `PATCH /admin/revisiones/:idVehiculo/finalizar` | `{mensaje,idVehiculo,estado,estadoSolicitud}`; inserta informe técnico | **Requiere revisión de DTO/parámetros opcionales**; 401 |

Fuentes: `admin/admin.controller.ts:8`, `admin.service.ts:11,157,242`.

### 1.5 Paths faltantes y contratos incompatibles

| Referencia frontend o funcionalidad | Realidad backend | Decisión del plan |
|---|---|---|
| `GET /propietario/resumen` | Faltante; API owner cae a `GET /vehiculos/mis-vehiculos` | Crear resumen real acotado y mantener inventario independiente |
| `GET /conductor/resumen` | Faltante | Crear agregado propio; listar servicios desde reservas con rol |
| `PATCH /conductor/disponibilidad` + `{disponible}` | Faltante | Reutilizar `/personas/conductor/disponibilidad` + `{disponibilidad}` |
| `PATCH /conductor/servicios/:id/aceptar` y `/rechazar` | Faltantes | Reutilizar `/reservas/:id/respuesta-conductor` + `{aceptar:true/false}` |
| `PATCH /conductor/servicios/:id/iniciar` y `/finalizar` | Faltantes, también sus transiciones | Crear acciones de ciclo de vida bajo `/reservas/:id/...` |
| `GET /admin/resumen` | Faltante; UI cae a usuarios | Crear métricas con fuente y periodo definidos |
| `PATCH /admin/usuarios/:id/estado` | Faltante | Usar `/suspender` o `/reactivar`; no enviar Pendiente |
| `/admin/aprobaciones` y `PATCH /admin/aprobaciones/:id` | Faltantes; «licencia/vehículo aprobado» no equivale a revisión técnica | Adaptar UI a `/admin/revisiones` y sus tres acciones |
| `POST /personas/roles` con `{roles:'Conductor'}` | Ruta existe; campo no permitido por DTO | Enviar `{}` con licencia vigente o `{licencia:{...}}`; releer perfil |
| Favoritos consultados en `/vehiculos/:id` | Endpoint exclusivo del dueño | Consultar `/vehiculos/catalogo/:id`; persistencia actual local |
| Decisión Esperar/Continuar sin conductor | Método `decidirSinConductor` existe, sin ruta | Exponer acción protegida después de cerrar confirmación |
| Orden, checkout Sandbox, PDF, editar reserva, revisión técnica | Endpoints existentes sin interfaz completa | Conectar; no inventar un segundo módulo equivalente |
| Recuperar/restablecer contraseña | API Flutter solo hace `Future.delayed`; no endpoint backend | Implementar recuperación Firebase con código OOB, sin éxito ficticio |

Constantes **sin llamadas actuales**: `favorites` (`/vehiculos/favoritos`),
`reservations` (`/reservas`), `driverTrips` (`/conductor/servicios`),
`adminApprovals`, `driverReviews`, `paymentMethods`, `payments`,
`paymentMethod`. Su presencia en `api_endpoints.dart` no demuestra una
integración ni un endpoint. Las rutas de tarjetas `/pagos/metodos*` no
existen y `metodo_pago` es un catálogo de proveedores, no una bóveda de tarjetas.

### 1.6 Catálogo de datos

Detalle de columnas/tipos en `docs/carman_tables.txt`. Los nombres de las
columnas documentadas se contrastaron con metadatos locales; esa comparación
no acredita todas las restricciones. `idPersona` vincula los roles; reserva
vincula cliente, vehículo y conductor opcional.

| Tabla | Datos/relaciones relevantes | Uso backend real y repercusión en UI |
|---|---|---|
| `persona` | Identidad, estado, actividad, email, UID; documento/usuario/UID únicos documentados | Auth, Personas, Admin, reservas/notificaciones; perfil propio |
| `cliente` | PK propia, `idPersona` único/FK | Reservas, pagos, calificaciones; titularidad |
| `propietario` | PK propia, `idPersona` único/FK | Vehículos y reservas; inventario propio |
| `conductor` | PK propia, `idPersona` único/FK, disponibilidad, calificación | Asignación/roles; promedio almacenado no se actualiza al crear reseña |
| `administrador` | `idPersona` único/FK, cargo/estado | Guard de administración |
| `licencia` | Una por persona, número único, vencimiento, estado, tipo, URL foto | Registro/renovación/rol/disponibilidad; no hay workflow de «revisor de licencias» |
| `punto_autorizado` | Nombre, ciudad, dirección y coordenadas públicas, activo | Catálogo, vehículos, reservas, rutas; no ubicación personal |
| `vehiculo` | Propietario, placa única, tarifa diaria DECIMAL, fotos JSON, puntos, tarjeta, estados de revisión | Inventario/catálogo/revisión; no combustible/transmisión/tarifa horaria documentados |
| `estado_tecnico_vehiculo` | FK vehículo, componentes, kilometraje, técnico, fecha, observaciones | Admin inserta al finalizar revisión; falta API para consultar historial |
| `reserva` | Fechas/horas planeadas, precio, estado, respuesta/decisión conductor, rechazados JSON, puntos | Todos los participantes; faltan acciones de inicio/final |
| `orden_de_pago` | Una por reserva, total, estado, `rutaPdf`; clave única compuesta para pago | PDF y checkout; no equivale a factura fiscal |
| `pago` | Reserva/orden, monto DECIMAL, tipo/estado, referencias Wompi únicas | Anticipo/restante; no liquidaciones a propietario/conductor |
| `metodo_pago` | Nombre único, proveedor, descripción, activo | LEFT JOIN en historial; checkout crea pago con método NULL |
| `documento` | LONGBLOB, tipo, origen/ID, fecha | PDF de orden; lectura pública de documentos personales no existe |
| `notificacion` | Destinatario/FK, reserva/pago opcionales, texto, fecha, leída | Bandeja propia; SMS opcional a teléfono coincidente verificado |
| `phone_verification` | HMAC de teléfono/código, persona, caducidad, intentos/cuota; sin FK documentada | OTP; jamás enviar a Flutter |
| `calificacion` | Cliente/reserva; vehículo **o** conductor, 1–5, comentario/fecha | Crear y consultar resumen sin autores ni texto libre público |
| `contrato_alquiler` | Reserva única, participantes, firmas, PDF, orden de firma y estado | **Sin servicio/ruta de negocio**, solo diagnóstico de existencia |
| `ruta` | FK reserva, origen/destino, coordenadas, distancia/duración/proveedor | **No se persiste desde `RutasService`**; calcula al consultar |
| `telemetria` | Vehículo, coordenadas, velocidad, timestamp | **Sin consumo de negocio**; no confundir con GPS voluntario |
| `ubicacion_compartida` (optativa) | PK reserva/persona, última posición y fecha; FK a ambas | Servicio existe con flag; tabla ausente en metadatos auditados |

Observaciones de esquema para implementación:

- `001_initial.sql` no contiene reservas/pagos/calificaciones y otras tablas,
  ni `vehiculo.precioPorDia`. Sus defaults difieren del DDL documental
  (`vehiculo` inicial en revisión, disponibilidad conductor distinta,
  dirección obligatoria, email único). **No sirve hoy para reproducir una
  base completa de ensayo sin reconciliación.**
- En la conexión auditada se confirmaron los dos UNIQUE de reseñas.
  No aparecieron CHECK de rango/XOR en el catálogo consultado. Mantener la
  validación de servicio/DTO y verificar la política de constraints en ensayo.
- `003` crea únicamente la última ubicación por persona/reserva y un índice
  de caducidad. No hay comprobación previa de existencia en el servicio:
  habilitar el flag con tabla ausente produciría errores.
- La lectura GPS elimina posiciones caducadas globalmente; caducidad visible
  de dos minutos no implica borrado físico exactamente a los dos minutos.
  El schedule actual es diario y las lecturas también limpian.
- **No ejecutar `db:migrate` ni el DDL documental sobre `carmandb`.** La
  reconciliación se diseña y valida en una base de ensayo aislada.

### 1.7 Estados actuales y transiciones incompletas

| Entidad | Estados/flujo comprobados | Trabajo necesario |
|---|---|---|
| Reserva | `Pendiente`, `Confirmada`, `Rechazada`, `Finalizada`, `Cancelada`, `EnCurso`; crear sin conductor → Confirmada; con conductor → Pendiente | No hay acciones para EnCurso/Finalizada/Rechazada; aceptar conductor sigue Pendiente |
| Respuesta conductor | `Pendiente`, `Aceptada`, `Sin_conductor`, NULL; rechazo guarda ID y reasigna o deja sin conductor | No interpretar rechazo individual como cancelación de la reserva |
| Decisión | NULL → `Esperar`/`Continuar` en servicio sin ruta | Continuar solo cambia decisión; debe resolver confirmación/precio |
| Orden | `Activa` → `Pagada` al completar suma aprobada; → `Anulada` al cancelar sin pagos bloqueantes | Añadir lectura de saldo/acciones; distinguir generación PDF posterior al commit |
| Pago | `Pendiente`, `En_proceso`, `Aprobado`, `Rechazado`, `Fallido`, `Cancelado`, `Reembolsado` | Webhook mapea cinco estados; no hay reembolso/conciliación operativa implementados |
| Tipo pago | `Anticipo`, `Restante`, `Completo` | Checkout actual usa Anticipo 50 % antes de inicio y Restante durante periodo; no asume Completo |
| Vehículo | `Activo`, `inactivo`, `En_mantenimiento`, `revision_pendiente`, `Rechazado` | UI debe representar inactivo/rechazado; dueño solo solicita Activo/inactivo con reglas |
| Solicitud revisión | `Sin_solicitud` → `Pendiente` → `Aprobada`/`Rechazada`; Aprobada → `Finalizada` | Necesaria lista de aprobadas para finalizar, hoy GET solo retorna pendientes |
| Persona | `Activo`, `Suspendido`, `Inactivo` | UI Admin confunde Inactivo con Activo; política de cambios debe proteger continuidad administrativa |
| Licencia | `Vigente`, `Vencida`, `Suspendida` | Flutter usa «En revisión/Verificada/Rechazada»; mapear vigencia sin atribuir revisión humana |
| Contrato | DDL: `Pendiente_Firma`, `Activo`, `Finalizado`, `Cancelado`; orden Propietario → Conductor → Cliente → Completado | No hay transiciones implementadas; módulo opcional independiente |

El cron de reasignación de conductores está en
`reservas/tareas-reservas/tareas-reservas.service.ts:14` cada 30 minutos.
En Vercel se omite `ScheduleModule` y `vercel.json` solo programa cuentas
inactivas: **no hay schedule equivalente para esa reasignación**.
Activar disponibilidad sí dispara una búsqueda desde Personas.

### 1.8 Correcciones priorizadas para el inicio de fase 4

| ID / prioridad | Hallazgo y evidencia | Criterio de cierre |
|---|---|---|
| B01 / P0 | Registro sin `persona` devuelve 500; DTO `registroInicial.dto.ts:14` | Entradas inválidas → 400 sin Firebase/INSERT |
| B02 / P0 | `verification.service.ts:101–109` consume JSON dos veces | Test con `Response` nativa + entrega/reenvío en cuenta de ensayo |
| B03 / P0 | Reservas con conductor quedan Pendiente; orden exige Confirmada (`reservas.service.ts:260`, `pagos.service.ts:90`) | Flujo aceptado/Continuar llega a un estado pagable definido |
| B04 / P0 | Crear reserva hace comprobación de solape e INSERT sin transacción/bloqueo compartido (`reservas.service.ts:108–182`) | Dos peticiones simultáneas no asignan el mismo vehículo/conductor en el mismo intervalo |
| B05 / P1 | Editar reserva usa `String(fechaDB).slice(0,10)` con posibles Date de mysql2; PATCH vacío puede recalcular/reasignar | Fechas DATE normalizadas, al menos un cambio, ninguna reasignación accidental |
| B06 / P1 | API de reserva no exige inicio futuro ni licencia del cliente para conducir; selección conductor no filtra persona suspendida | Reglas comunes explícitas: conducción propia/con conductor, adultos/licencia/estado, fronteras horarias |
| B07 / P1 | Estado vehículo se escribe sin revisar revisión técnica ni reservas (`vehiculos.service.ts:258`) | No reactivar mantenimiento/rechazo ni invalidar reservas aceptadas por un toggle |
| B08 / P1 | DTO resultado técnico permite omitir técnico/documento; SQL envía `undefined` a `execute` (`admin.service.ts:287`) | Decidir obligatoriedad; usar valores válidos/null, evitar 500 |
| B09 / P1 | Cambiar teléfono por perfil puede dejar activación bloqueada; SMS rechaza número Firebase distinto | Flujo explícito de cambio/verificación y recuperación sin perder acceso |
| B10 / P1 | Reasignación cron no existe en serverless; nota del apartado anterior | Job idempotente autenticado y ensayo de concurrencia con acciones manuales |
| B11 / P1 | Calificar conductor no actualiza `conductor.calificacion`, usado para asignar | Fuente consistente para ranking y promedio de panel |
| B12 / P1 | Respuesta de disponibilidad retorna IDs de reservas asignadas por búsqueda **global** (`personas.service.ts:771`) | Retornar solo reservas relacionadas o un conteo no identificable |
| B13 / P2 | Admin lista datos amplios sin paginación, revisiones solo pendientes; suspensión permite al propio/último admin | DTOs paginados, detalle limitado por uso y reglas de continuidad acordadas |
| B14 / P2 | IDs convertidos con `Number()` en reservas/vehículos, fechas DTO aceptan ISO más amplio que DATE; `FROM Pago` capitalizado | Normalizar ID entero positivo, DATE/hora, casing SQL y errores 400/404 reproducibles |

P0 identifica bloqueos de funcionamiento antes de conectar pantallas.
Los riesgos de concurrencia se deducen del código; no se intentó provocarlos
en la base actual.

## 2. Fase 2 — Mapa completo del frontend existente

### 2.1 Stack, estado y navegación

- **Flutter/Dart**, `material_ui` y Material 3. Dependencias en
  `frontend/pubspec.yaml`, no en un `package.json` frontend.
- Riverpod 3: `NotifierProvider`/`FutureProvider`; GoRouter 18.
  `http` en `ApiClient`, modelos manuales y repositorios demo/API.
- `shared_preferences` almacena sesión, favoritos y avisos leídos;
  `image_picker`, `flutter_map`, `latlong2`, `geolocator`, `intl` ya existen.
  Mantener este stack y no añadir otro gestor de estado/UI/HTTP.
- `StatefulShellRoute.indexedStack`: Explorar, Favoritos, Viajes, Perfil.
  Pantallas de rol son rutas secundarias abiertas desde perfil.
- Solo welcome/login/register/OTP/forgot/reset son públicas en el router.
  El catálogo backend público no implica que Flutter permita navegarlo
  sin sesión.
- Router comprueba autenticación, no roles. Las tres pantallas de rol
  bloquean dentro de `build`, **después** de observar sus controladores.
  Se necesitan redirects/capacidades previos y aislamiento del estado.

### 2.2 Las 30 pantallas y su estado

«Conectado parcial» significa que hay llamada API, no que su E2E esté
certificado. «Mockeado» también cubre acciones locales o placeholders
visibles. Los nombres corresponden a archivos bajo
`frontend/lib/features/<módulo>/presentation/screens/`.

| Pantalla / ruta | Estado actual en modo API | Pendiente concreto |
|---|---|---|
| `welcome_screen` `/welcome` | Vista local de entrada | Mantener estilo/navegación |
| `login_screen` `/login` | Conectado parcial: login, verificación y perfil | Sesión válida, refresh, expiración, retorno a ruta solicitada |
| `register_screen` `/register` | Conectado parcial cliente; propietario bloqueado, conductor necesita URL documental no resuelta por UI | Onboarding real por rol, activación y errores de cuenta ya creada |
| `otp_screen` `/verify-otp` | Conectado parcial correo/SMS/confirmar | Corregir B02; mantener cuota/reenviar/consultar activación |
| `forgot_password_screen` `/forgot-password` | **Mockeado** en repositorio API | Solicitud real de recuperación |
| `reset_password_screen` `/reset-password` | **Mockeado** en repositorio API | Validar código OOB y confirmar cambio real |
| `home_screen` `/home` | Conectado catálogo; filtros/presentación parciales | Estado vacío real y métricas/especificaciones solo con fuente |
| `search_screen` `/search` | Puntos conectados; varios filtros sin soporte | Solo filtros de datos disponibles; horarios diarios backend |
| `results_screen` `/home/results` | Conectado catálogo, orden local | Paginación/filtros servidor y conteo total real |
| `vehicle_detail_screen` `/vehicle/:id` | Conectado detalle/promedio; especificaciones por defecto y mensaje anfitrión ficticio | Separar ficha pública/privada, campos desconocidos, eliminar falso envío |
| `gallery_screen` `/gallery/:id` | Fotos del vehículo; algunas acciones solo snackbar | No confirmar compartir/guardar sin efecto real |
| `map_screen` `/map` | Mapa live con puntos del catálogo; maqueta en demo | Estados error/carga/vacío y distinguir punto autorizado de posición del auto |
| `favorites_screen` `/favorites` | Favoritos locales; API usa detalle privado equivocado | Detalle público, favoritos por cuenta, tolerar vehículo no disponible |
| `checkout_screen` `/checkout` | **Conectado parcial a crear reserva**, sin cobro; `solicitarConductor:false` | Opción conductor, confirmación y pago Sandbox posterior |
| `booking_success_screen` `/booking/success` | Consume reserva en memoria; mensajes live sin cobro | Restaurar por ID y mostrar estado confirmado por servidor |
| `payment_failed_screen` `/booking/failed` | **Mockeado**; fallback `MockData`, vencimiento local | Estado de pago real; no inventar retención de inventario |
| `reservation_expired_screen` `/booking/expired` | **Mockeado**, vehículo semilla | No activar live hasta existir política de expiración backend |
| `payment_methods_screen` `/payment-methods` | Demo; acceso live bloqueado | No convertir catálogo `metodo_pago` en tarjetas guardadas |
| `payment_history_screen` `/payment-history` | Conectado al historial propio, lectura | Paginación, filtros, detalle de orden/pago y reintento |
| `trips_screen` `/trips` | Conectado lista multirrol | Filtro por relación, paginación y estados exactos |
| `trip_detail_screen` `/trip/:id` | Conectado cancelar/reseña vehículo/ruta | GET por ID, editar, conductor, pago/PDF, permisos de acción |
| `profile_screen` `/profile` | Perfil local desde login; menú multirrol; acciones de ayuda estáticas | Refrescar perfil, onboarding, acciones de soporte verificables |
| `edit_profile_screen` `/profile/edit` | PATCH real nombre/apellido/teléfono/ciudad | E.164 consistente, reverificación, imagen persistida |
| `notifications_screen` `/notifications` | GET/PATCH reales con estado optimista local | Rollback/refetch ante fallo, contador y scope por persona |
| `license_verification_screen` `/license` | Selector/fotos demo; submit live bloqueado | Carga documental segura y POST/PUT real |
| `license_review_screen` `/license/review` | Estado derivado de perfil; revisión automática solo demo | Mostrar Vigente/Vencida/Suspendida; no fingir aprobación humana |
| `owner_dashboard_screen` `/owner` | **Mixto**: inventario real por fallback; estados locales, agregados por defecto | Resumen real, editar, estados/revisión HTTP, reservas propias |
| `add_vehicle_screen` `/owner/add-vehicle` | **Incompleto**: no recoge IDs de puntos/fotos/tarjeta requeridos | Completar formulario y acceso al primer vehículo sin exigir rol previo |
| `driver_dashboard_screen` `/driver` | **Mockeado funcional en demo; API desconectada** | Rehacer contratos, solicitudes, disponibilidad, ciclo de servicio |
| `admin_dashboard_screen` `/admin` | **Mixto**: usuarios por fallback; cambios y aprobaciones desconectados | Usuarios con roles reales, revisión técnica y resumen real |

Pantallas/capacidades **por crear**: editor y detalle privado de vehículo,
solicitud/historial técnico, edición de reserva, detalle de orden y checkout
Sandbox/retorno, lector PDF autenticado, lista/detalle de revisiones aprobadas,
detalle admin de usuario y onboarding documental.

### 2.3 Controladores, repositorios y coherencia de datos

| Controlador | Estado/métodos y conexión | Ajuste necesario |
|---|---|---|
| Auth | Sesión/usuario, envío/error, verificación pendiente; login/register/verify/resend/reset/logout | Renovación; no restaurar solo por usuario local; refrescar claims/perfil |
| Catalog | Query/lista/loading/error; actualizar filtros, refresh, sort; evita respuestas antiguas por request ID | Aplicar filtros realmente en backend o declarar los locales |
| Favorites | Set IDs y toggle en SessionStore; FutureProvider resuelve vehículos | Scope por cuenta y ruta pública correcta |
| Booking | Draft/lastReservation/failure/isPaying; prepara fechas/recogida; `pay()` crea reserva | Nombrar y separar reservar/pagar, permitir conductor; no imponer datos de pago demo |
| Payment | Métodos semilla, selección/alta/baja/default locales | Crear repositorio de órdenes/pagos; mantener la demo explícita |
| Trips | Reservas/tab/loading/error/actionInProgress; fetch/cancel/review | Conservar relación y capacidades, GET detalle, editar y estados exactos |
| Profile | Usuario/saving/error; PATCH propio y addRole | Body rol correcto; releer perfil tras mutar identidad/roles |
| License | Fotos, fechas, estado/error, timer demo de 15 s | Live bloqueado; persistencia y estados de vigencia reales |
| Notifications | Items/loading/error; lectura optimista + persistencia local | Revertir o refetch al fallar; aislar al cambiar de cuenta |
| Owner | Stats/listings/loading/publishing; load/publish/setStatus | `setStatus` solo cambia memoria; publicar agrega revisión/+1 reserva ficticios |
| Driver | Data/loading/error/actionTripId; aceptar/iniciar/finalizar/rechazar | Paths/body correctos; aplicar respuesta/refetch, no sumar ganancias localmente |
| Admin | Data/loading/error/actionId; updateUserStatus/reviewApproval | Separar usuarios de revisión técnica; acciones concretas existentes |

Repositorios: auth, vehicle, owner, driver y admin contienen Demo/API;
booking/profile/notification tienen interfaz/demo y `api_*` separados.
`ApiTripMapRepository` y `ApiPaymentHistoryRepository` son live específicos.
Los modelos (11 archivos) son manuales: Vehicle/PickupPoint, VehicleQuery,
UserProfile, BookingDraft/Reservation/Pricing, PaymentMethod,
PaymentHistoryEntry, Owner/Driver/Admin, AppNotification y TripRoute/Location.

Problemas concretos a corregir en los adaptadores:

1. `ApiClient` transforma arrays a `{data:...}`, lo que hace válido el
   fallback de mis vehículos/puntos. No cambiarlo suponiendo que falla por
   recibir un array. Carece de PUT, binarios PDF y refresh; 401/403 se
   convierten en la misma `AuthException`.
2. Admin devuelve flags `cliente/conductor/propietario` en raíz numéricos;
   `ApiMappers.adminDashboard` busca `roles`. Infiere Cliente, verificado
   `true`, viajes `0` y métricas sin fuente. `Inactivo` se interpreta Activo.
3. `OwnerVehicleStatus` no contempla inactivo/Rechazado y cae en disponible.
   El mapper inventa próximo mantenimiento a 90 días/documentos al día;
   la UI muestra «Comisión 15 % · Liquidación semanal» sin soporte.
4. Driver espera `idServicio`, `fechaHora`, ganancia y datos anidados;
   reservas entrega `idReserva`, fechas separadas y estados de respuesta.
   `Finalizada` cae en oferta en `DriverTripStatus.fromApi`.
5. Reservation conserva `canReview`, pero pierde los demás roles/acciones
   y respuesta/decisión conductor. Pendiente se reduce a pendingPayment.
   Dueño/conductor pueden ver botones de cancelar que solo acepta el cliente.
6. Catálogo acepta solo `ciudad`; `VehicleQuery.toApiJson` manda categoría,
   texto, fechas, plazas, precio y otros campos. API repository no filtra
   localmente con `matches`: varios controles no afectan el resultado.
7. Datos ausentes se convierten en eléctrico/automático/tracción delantera/
   etiqueta 0, fechas aproximadas o ceros. Reemplazar defaults de negocio
   live por campos opcionales y «No disponible», conservando el diseño.
8. `AuthController.build` restaura usuario local sin validar token; se ignoran
   refreshToken/expiresIn del login. Varios providers privados no dependen
   del ID de sesión y pueden conservar datos al cambiar de cuenta.
9. Al cambiar de teléfono, la UI copia el usuario sin actualizar verificación.
   El guard puede bloquearlo y el servicio SMS rechazar un número distinto
   ya asociado en Firebase: necesita flujo completo, no solo PATCH.

Fuentes principales: `data/remote/api_client.dart`,
`api_mappers.dart:172,299,381,540`, `data/repositories/api_profile_repository.dart`,
`features/owner/application/owner_controller.dart:85,131`,
`features/auth/application/auth_controller.dart:69`,
`data/models/owner_models.dart:21`, `driver_models.dart:40`.

### 2.4 Diseño que debe preservarse

| Elemento | Regla para las nuevas vistas |
|---|---|
| Marca | `AppColors.primary #6B38D4`, `primaryViolet #7C5AF6`, `deepViolet #5B35D6`, `softLavender #F1EEFC`; gradiente existente |
| Superficies/texto | `canvas #F6F6F8`, `surface #FFFFFF`, `graphite #17171B`, `onSurface #151517`, `secondaryText #5F5F69`, `border #E4E4EA` |
| Estados | success `#0E8A75`, warning `#B45309`, error `#BA1A1A`; acompañados de texto/icono |
| Tipografía | Manrope local; `AppTheme`: display 32, headlines 26/21/17, títulos 15.5/14.5, body 15/13.5/11.5, price 22 |
| Espaciado | `AppSpacing` 2/4/8/12/16/20/24/32/48; usar tokens y composición existente |
| Radios | `AppRadius.card` 18, control 14, sheet 24, pill 999 |
| Responsive | Tokens 700/1050, contenido 1240, lectura 780; shell real cambia a sidebar a 720; respetar wrappers actuales |
| Anchos existentes | Owner 1240, admin 1000, driver/detalle 900, checkout 960; formulario de vehículo 760 |
| Tablas/listas | Tabla paginada en escritorio, tarjetas en móvil con los mismos datos/acciones; controles Material ya disponibles |

Reutilizar:

- `CarmanTopBar(title, subtitle, actions, onBack)` y `ResponsiveRouteFrame`.
- `CarmanCard(child, padding, onTap, showShadow)`; `SectionHeader` y `KeyValueRow`.
- `CarmanButton(label,onPressed,isLoading,variant)` con variantes
  primary/secondary/outline/ghost/dark/danger.
- `CarmanTextField(controller,label,validator,enabled,maxLength,...)`,
  `PasswordTextField`, `Form` y `Validators`.
- `StatusBadge`, `RatingBadge` solo con datos reales, `IconTile`,
  `CarmanFilterChip`, `SegmentedControl`, `SelectPill`.
- `LoadingList`/`CenteredLoader`, `EmptyState`, `ErrorView(onRetry)`,
  `InfoBanner` y `showCarmanSnack` para estados distintos.
- `showCarmanSheet`, `SheetHeader`, `SheetBody`, `showConfirmDialog`;
  `CarmanImage`/`CircleAvatarImage`, `FadeSlideIn`/`HoverLift` donde ya encajan.
- `flutter_map` para mapa real; `MapPreview` es ilustrativo y no acredita GPS.

Fuentes: `core/theme/*`, `shared/widgets/*`. No se propone rediseño global.
Cada nueva pantalla debe conservar posición de navegación, jerarquía visual,
tipografía, colores, estados de carga y comportamiento responsive.

## 3. Fase 3 — Plan de integración listo para ejecutar

### 3.1 Contratos transversales propuestos

Son contratos futuros, **no endpoints ya implementados**:

- Identidad desde token; rol activo es contexto de UI, no autorización
  concedida por un parámetro. Filtrar siempre recursos por participación.
- Ampliar listas existentes sin romper sus claves: por ejemplo
  `{reservas:[...],total,pagina,tamanoPagina}` y
  `{usuarios:[...],total,pagina,tamanoPagina}`. Página ≥1, tamaño 20 por
  defecto, máximo 100, orden estable con ID de desempate.
- `estado`, `rol`, `desde`, `hasta`, `buscar` mediante DTOs validados.
  Ventana temporal documentada en `America/Bogota`. SQL parametrizado y
  columnas de orden con lista permitida.
- Montos en COP con representación decimal explícita; conversión a
  centavos para Wompi sin recalcular tarifas en widgets.
- Una reserva de detalle incluye estados separados:
  `estado`, `estadoRespuestaConductor`, `decisionSinConductor`, pago y
  `rolesRelacionados`; añadir `accionesPermitidas` calculadas por backend
  (`editar,cancelar,responder,iniciar,finalizar,pagar,calificarVehiculo,
  calificarConductor,verPdf,compartirUbicacion`).
- La API vuelve a comprobar cada acción aunque el botón esté habilitado.
  Desconocido/no soportado = `null`/capacidad ausente, no un cero o éxito ficticio.
- En mutaciones: deshabilitar doble envío, usar respuesta del servidor o
  refetch; diferenciar fallo antes/después del commit. No repetir POST
  automáticamente si ya se confirmó creación.
- Separar 401 de 403; invalidar datos privados por identidad al logout/cambio
  de cuenta. Preservar borrador ante un fallo recuperable.

### 3.2 Endpoints nuevos y ampliaciones seleccionadas

| Contrato propuesto | Permiso / cuerpo o filtro | Respuesta mínima y persistencia |
|---|---|---|
| `GET /reservas/:idReserva` | V; participante | `{reserva}` con campos/acciones anteriores; joins existentes |
| Ampliar `GET /reservas/mis-reservas` | V; `rol=Cliente/Propietario/Conductor`, estado, fechas, página | Mismo envelope paginado; intersección con identidad del token |
| `PATCH /reservas/:idReserva/decision-sin-conductor` | Cliente titular; `{decision:'Esperar'|'Continuar'}` | `{idReserva,estado,estadoRespuestaConductor,decisionSinConductor,precioEstimado}` |
| `PATCH /reservas/:idReserva/iniciar` | Propuesta: conductor asignado si existe; cliente habilitado si no | Estado EnCurso; bloqueo reserva/vehículo, horario y pago según regla acordada |
| `PATCH /reservas/:idReserva/finalizar` | Mismos actores de operación | Estado Finalizada; condiciones de entrega/saldo definidas; sin simular liquidación |
| `GET /pagos/reservas/:idReserva/estado` | Cliente titular | Orden, total, aprobado, saldo, intentos mínimos, `puedePagar`, documento; lectura sin crear orden |
| `GET /propietario/resumen?desde&hasta` | V + propietario propio | Vehículos por estado, reservas por estado, volumen cobrado; métricas no disponibles null |
| `GET /conductor/resumen?desde&hasta` | V + conductor propio | Disponibilidad, licencia, servicios programados/finalizados, promedio/total reseñas; sin ganancias ficticias |
| `GET /admin/resumen?desde&hasta` | A | Usuarios/vehículos por estado, reservas, revisiones pendientes, volumen pagos aprobados |
| Ampliar `GET /admin/usuarios` | A; estado/rol/buscar/página | Roles booleanos consistentes, estado exacto, total; detalles personales solo donde se necesitan |
| Ampliar `GET /admin/revisiones` | A; estado/página | Pendientes y aprobadas/finalizadas con identidad estable `idVehiculo` |
| `GET /admin/revisiones/:idVehiculo` | A | Solicitud actual e informes técnicos; sin convertirlo en aprobación de licencia |
| `GET /vehiculos/:idVehiculo/historial-tecnico` | Propietario del vehículo | Informes técnicos propios, paginados, campos minimizados |
| `GET /personas/licencia` | V; propia | Número/tipo/vencimiento/estado y referencia protegida de imagen |
| `POST /auth/recuperacion` | P; email validado | Mensaje genérico; envío Firebase real con límites |
| `POST /auth/restablecer` | P; código OOB y contraseña válida | Confirmación Firebase; nunca resetear solo por email |
| `POST /auth/refresh` | Refresh token; validación Firebase y estado de cuenta | Nuevo ID token/expiración; no tratarlo como acceso a recursos |
| Job interno de reasignación | Secreto cron, endpoint idempotente a definir junto al schedule | Conteos operativos, sin IDs ajenos ni datos personales |

Carga documental: añadir capacidad autenticada en `archivos/`, con propósito
(`licencia`, `tarjetaPropiedad`, `fotoVehiculo`), tamaño/tipo validados y
propiedad comprobada por el servidor. Resolver almacenamiento y contrato de
referencia antes de implementar el formulario: `documento` ya guarda
binarios/origen, pero su endpoint actual **solo lee órdenes de pago**.
No usar `local://`, assets demo o URLs inventadas. Preferir onboarding
cliente verificado → documentos → conductor/primer vehículo, para poder
vincular la carga a una persona autenticada.

El contrato de cargas debe definir expresamente:
`POST /archivos/cargas` → `{idDocumento,referencia,proposito}`; lectura privada
por titular y, cuando corresponda, administrador; fotos públicas solo después
de asociarlas a un vehículo publicable. Los DTOs de licencia/vehículo deben
aceptar referencias verificadas de ese contrato, o URLs emitidas por el
servidor con propiedad comprobable. Determinar si basta el esquema existente
o se necesita metadata adicional en la base de ensayo. No reutilizar sin
autorización la lectura PDF exclusiva del cliente.

### 3.3 Pantallas y módulos, en orden de construcción

Cada módulo tiene exactamente tres bloques de trabajo planificado. **Ninguno
se ejecutó en esta auditoría.** Las referencias M0–M6 identifican el alcance
que se puede elegir al iniciar fase 4.

#### M0 — Correcciones backend y contratos comunes

1. **Backend/datos:** resolver B01–B12 según dependencias; reconciliar esquema
   de ensayo, normalizar fechas/IDs y estados, decisiones/transacciones de
   reserva. Definir confirmación, conducción propia, pago previo y cierre.
2. **Contrato/base Flutter:** completar PUT/binarios/refresh en ApiClient
   cuando exista soporte backend; mappers exactos, permisos por recurso,
   providers por cuenta, campos nullable y manejo 401/403.
3. **Aceptación:** regresión de los dos defectos reproducidos; token revocado,
   suspendido/no verificado, recurso ajeno, carreras de reservas y estados
   inválidos. Login/verificación de ensayo utilizable antes de continuar.

#### M1 — Cliente: cuenta, licencia, catálogo y favoritos

1. **Backend:** resolver activación/recuperación, lectura/licencia y cargas;
   filtros de catálogo basados en columnas reales, disponibilidad por fechas,
   paginación. No ofrecer filtro de combustible si no hay dato.
2. **Flutter:** completar login/OTP/recuperación y licencia; mantener ficha,
   galería, mapa, búsqueda y favoritos. Selector de horarios permitidos,
   resumen de filtros, vacíos/errores reales, favoritas por usuario.
3. **Aceptación:** registrar/activar/login/recuperar/renovar sesión en ensayo;
   licencia vigente/vencida/suspendida, filtro efectivo, cambio de cuenta,
   detalle público de vehículo ajeno y navegación responsive.

#### M2 — Cliente: reserva, viaje, pagos y reseñas

1. **Backend:** GET detalle, editar/cancelar con reglas, decisión sin
   conductor y confirmación; estado de orden/saldo, checkout/webhook Sandbox,
   historial paginado, inicio/finalización y reseñas por objetivo.
2. **Flutter:** conservar `/checkout` como confirmación de reserva y permitir
   conductor. Añadir `/trip/:id/edit`, `/trip/:id/payment`, lector
   `/payment-order/:id`, y retorno de checkout que **consulta** estado al
   servidor. Detalle de viaje con acciones por rol, ambos tipos de reseña
   y revisión de mensajes de éxito/fallo. Notificaciones enlazan al detalle.
3. **Aceptación:** sin/con conductor → confirmación → orden → anticipo →
   inicio → restante → finalización → reseñas/PDF. Webhook duplicado,
   rechazado y monto distinto; actualización de UI tras recarga. Cancelar
   sin pagos permitido y con pagos bloqueantes rechazado. No interpretar
   una URL de retorno como pago aprobado.

#### M3 — Propietario: inventario, publicaciones y revisión

1. **Backend:** usar POST/PATCH/estado/solicitar-revisión existentes; resumen
   propio e historial técnico, reglas B07 y reservas filtradas por dueño.
   El primer vehículo activa propietario en la transacción ya existente.
2. **Flutter:** permitir onboarding desde perfil sin bucle de «rol requerido».
   Completar `add_vehicle_screen` con puntos públicos, tarifa diaria y archivos.
   Añadir `/owner/vehicles/:id`, `/owner/vehicles/:id/edit`,
   `/owner/vehicles/:id/revision`; conservar cards/resumen. Toggle llama
   API y refleja estados reales; historial/solicitud con motivos.
3. **Aceptación:** publicar/editar/pausar/reactivar propio; negar vehículo ajeno;
   recargar confirma persistencia. Revisión bloquea disponibilidad según
   política; no se afirma mantenimiento futuro ni liquidación sin fuente.
   Errores no se muestran como inventario vacío exitoso.

#### M4 — Conductor: servicios y disponibilidad

1. **Backend:** resumen propio; listado de reservas como conductor;
   disponibilidad y respuesta en endpoints existentes; reutilizar acciones
   de inicio/finalización de M2. Reasignación sin tomar servicios ajenos.
2. **Flutter:** adaptar dashboard y sheet al ID de reserva, fechas y estados
   separados; solicitud → aceptar/rechazar → detalle → iniciar/finalizar.
   Añadir historial filtrable con paginación y enlace a licencia. Mensajes
   hablan de servicio finalizado, no de dinero abonado sin liquidación.
3. **Aceptación:** conductor no asignado no puede responder; licencia
   inválida impide disponibilidad; rechazar reasigna sin cancelar al cliente;
   doble clic/reintento no duplica recargo. No aceptar otra acción fuera
   de estado; GPS opcional no bloquea el servicio.

#### M5 — Administración: usuarios y revisión técnica

1. **Backend:** B08/B13, filtros/paginación y resumen; detalle de revisión,
   aprobadas para finalizar, técnicos/observaciones válidos; probar rutas
   existentes de suspender/reactivar y transacciones de informe.
2. **Flutter:** conservar Resumen/Usuarios y adaptar Aprobaciones a
   **Revisiones técnicas**. Tabla/cards con búsqueda, rol/estado y paginación;
   `/admin/users/:id` y `/admin/revisions/:id`, motivo de rechazo obligatorio
   y formulario técnico. Validación visible antes de enviar.
3. **Aceptación:** 403 para no admin; no autoconceder rol; cambios visibles
   después de recargar. Pendiente → Aprobada → Finalizada y rechazo con motivo;
   conflicto de dos administradores informado; ninguna «licencia aprobada»
   inferida de una revisión de vehículo.

#### M6 — Capacidades opcionales posteriores

**Corte posterior:** favoritos sincronizados desplegados después de que
el usuario confirmara la creación de la tabla en TiDB; falta verificación
autenticada y no se ejecutó migración automatizada en `carmandb`. Ver
[AVANCE_FASE4_M6_FAVORITOS.md](AVANCE_FASE4_M6_FAVORITOS.md).
Los puntos de auditoría anteriores describen el estado previo a este corte.

1. **Delimitar producto/datos:** contratos y firmas, favoritos sincronizados,
   liquidaciones/comisiones, revisión humana de licencias, chat/soporte y
   GPS voluntario. Hoy no tienen backend completo equivalente.
2. **Diseñar por capacidad elegida:** contrato propio, permisos, tablas
   adicionales solo si son necesarias y aprobadas; reutilizar widgets y
   endpoints existentes de ruta/GPS al habilitarlo.
3. **Aceptación independiente:** retención/TTL GPS real, consentimiento y
   stopping; contratos por firmante/orden; trazabilidad financiera si se
   elige liquidar. No condicionan la entrega básica a promesas demo.

### 3.4 Qué métricas pueden mostrarse realmente

| Métrica | Fuente posible | Regla de presentación |
|---|---|---|
| Inventario propio por estado | Vehículo → propietario → persona | Conteo real |
| Reservas por rol/estado | Reserva con joins al participante | Diferenciar solicitadas, programadas, en curso y finalizadas |
| Reservas creadas hoy | `fechaHoraReserva` | Usar hora Colombia |
| Servicios programados hoy | `fechaInicioServicio` + conductor | No llamarlos servicios realmente realizados hoy |
| Valoración | AVG/COUNT calificación por objetivo | Sin reseñas → sin nota; revisar ranking almacenado del conductor |
| Volumen cobrado asociado a vehículos | SUM pagos Aprobado de reservas del dueño | Incluye componentes del total; **no es ganancia neta ni liquidación** |
| Usuarios/conductores/vehículos activos | Persona, licencia/disponibilidad, vehículo | Definición explícita por cada contador |
| Ocupación programada | Intervalos de reservas y capacidad del inventario | Definir periodo/denominador; no llamarla ocupación real histórica |
| Ganancias del conductor, comisión 15 %, abonos semanales | No hay registro contable de distribución | No disponibles hasta módulo financiero |
| Horas conectado, tasa de aceptación histórica | No hay eventos de disponibilidad/ofertas completos | No disponibles; JSON rechazados no sustituye historial de ofertas |
| Próximo mantenimiento/documentos al día | Hay informes/URLs, no calendario ni certificación integral | No inferir 90 días ni `true` |
| Hora real de inicio/final y tiempo efectivo | Solo fechas planeadas en esquema actual | Requiere metadata de eventos si se necesita esa medición |

Ejemplos de consultas **propuestas, no ejecutadas** para agregados:

```sql
-- Inventario propio: la identidad es del token.
SELECT v.estado, COUNT(*) AS total
FROM vehiculo v JOIN propietario pr ON pr.idPropietario = v.idPropietario
WHERE pr.idPersona = ?
GROUP BY v.estado;

-- Volumen de pagos aprobados asociado a reservas de vehículos propios.
-- No multiplicar estos importes por joins a reseñas o informes técnicos.
SELECT COALESCE(SUM(p.monto), 0) AS volumenCobrado
FROM pago p JOIN reserva r ON r.idReserva = p.idReserva
JOIN vehiculo v ON v.idVehiculo = r.idVehiculo
JOIN propietario pr ON pr.idPropietario = v.idPropietario
WHERE pr.idPersona = ? AND p.estado = 'Aprobado'
  AND p.fechaHoraPago >= ? AND p.fechaHoraPago < ?;

-- Servicios del conductor actual; estado de reserva, no de pago.
SELECT r.estado, COUNT(*) AS total
FROM reserva r JOIN conductor c ON c.idConductor = r.idConductor
WHERE c.idPersona = ?
GROUP BY r.estado;

-- Panel admin: contador de solicitudes, no aprobaciones de licencias.
SELECT estado_solicitud_revision, COUNT(*) AS total
FROM vehiculo
GROUP BY estado_solicitud_revision;
```

### 3.5 Pruebas de aceptación antes de dar un módulo por completo

| Área | Casos obligatorios cuando se ejecute |
|---|---|
| Permisos | Sin token, token inválido/revocado, suspendido, sin verificación; rol correcto y recurso ajeno; usuario multirrol |
| CRUD | Crear fixture, leer, editar, releer; cancelar/desactivar según dominio; DELETE real solo donde existe (GPS); sin borrado físico inventado de reservas/usuarios |
| Concurrencia | Solapes vehículo/conductor, dos revisores, doble checkout, dos reseñas del mismo objetivo, webhook duplicado |
| UI | Loading/vacío/error/retry, validación campo, 401 vs 403, conflicto, recurso eliminado/no disponible, sin datos de otra sesión |
| Persistencia | Recargar navegador y abrir deep link refleja DB; nunca depender solo de memoria para un resultado de negocio |
| Diseño | Móvil 360/390, tablet ~768, escritorio 1280/1440; sin overflow, foco/teclado, etiquetas accesibles y tokens actuales |
| Externos | Firebase correo/SMS controlados, Wompi Sandbox, Mapbox disponible/no configurado/timeout; no confundir cola SMS con entrega |
| Calidad | Backend build/tests; Flutter analyze/tests; pruebas nuevas de contratos reales y navegador live sin errores de consola |

Extender suites existentes:
`backend/src/auth/verification.service.spec.ts`,
`personas/personas.service.spec.ts`, `reservas/reservas.service.spec.ts`,
`pagos/pagos.service.spec.ts` y tests HTTP; añadir cobertura Admin donde falta.
En Flutter: `api_*_test.dart`, `panels_test.dart`, `layout_smoke_test.dart`,
`responsive_test.dart` y navegación live por roles. `e2e_flow_test.dart`
actual y pruebas Demo de paneles no certifican el servicio real.

## 4. Decisión de ejecución — preparada, no iniciada

**Primer alcance recomendado:** M0, luego M1 y M2. Propietario/conductor/admin
se implementan en M3/M4/M5 cuando los contratos de reservas estén estables.

Para iniciar una sesión de implementación basta indicar, por ejemplo:

> Ejecuta la fase 4, empezando solo por M0 de
> `docs/PLAN_PANELES_POR_ROL.md`. Tras validar ese módulo, entrega resultados
> y pendientes antes de continuar.

Dejar identificados al elegir la ejecución:

- Entorno de ensayo y cuentas controladas disponibles por rol; no entregar
  contraseñas/tokens en documentos ni trazas compartidas.
- Política de confirmación con conductor, actor de entrega/devolución,
  licencia para conducir y pago exigido para iniciar/finalizar. La propuesta
  de actores está en 3.2; debe quedar una única regla en servicio y UI.
- Almacenamiento de archivos y referencia autenticada; si necesita cambio
  de esquema, validarlo primero fuera de `carmandb`.
- Alcance financiero inicial: checkout **Sandbox**, historial/orden; las
  liquidaciones/contratos/chat son capacidades M6 a elegir explícitamente.

Al retomar: revisar `git status`, conservar cambios previos y DDL/documentos,
leer este plan y la evidencia HTTP, y ejecutar solo el módulo elegido.
La futura publicación en Vercel queda después de los criterios de aceptación,
con build Linux y comprobación del despliegue correspondiente.
