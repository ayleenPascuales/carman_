# Avance de fase 4 — correcciones de fase 1 y M0

**Estado: M0 en ejecución parcial, no aprobado como completo.**
Este documento registra cambios posteriores a la auditoría del 26 de noviembre.
Los resultados originales en `AUDITORIA_HTTP_2026_11_26.md` son evidencia
histórica del código **antes** de estos arreglos, no una nueva prueba HTTP.

## Correcciones implementadas

| Hallazgo del plan | Cambio actual | Comprobación pendiente |
|---|---|---|
| B01: 500 sin `persona` | DTO exige objeto definido y valida su contenido; POST inválido devolvió HTTP 400 | Registrar caso válido solo en entorno de ensayo |
| B02: doble consumo Firebase | Parsear `Response` una vez; prueba con `Response` nativa | Envío de correo con cuenta de ensayo autorizada |
| B03: conductor aceptado y decisión Continuar sin confirmación | Ambos estados pueden pasar a `Confirmada`; ruta protegida para decisión; acciones protegidas `iniciar` y `finalizar` comprueban titularidad, estado y pagos | Flujo real reserva → orden → Wompi Sandbox → servicio en DB de ensayo |
| B04: carrera en creación | Transacción con locks de persona/vehículo y comprobación actual de solape del conductor; cliente implícito en la misma transacción; aviso después del commit | Pruebas concurrentes con dos clientes/conductores reales en DB aislada, resolver deadlocks/reintentos |
| B05: PATCH fechas y reasignación | DATE de mysql2 normalizado a Colombia; exige cambio real, inicio futuro; preserva conductor aceptado y recalcula su precio si cambia horario | Fechas parciales y pagos/orden en ensayo |
| B06: cliente sin licencia y conductor inactivo | Sin conductor exige licencia vigente hasta fin; candidatos excluyen personas suspendidas y licencias que expiran antes del fin | Confirmar reglas de negocio de conducción propia/servicio y ensayar fronteras |
| B07: toggle vehículo | Transacción/lock; impide estados de revisión y desactivar con reservas activas | Ensayar carrera con revisión y nuevas reservas |
| B08: resultado técnico | Envía `null` en lugar de `undefined` al SQL para campos opcionales | Registrar informe técnico con administrador de ensayo |
| B09: teléfono cambiado sin reverificación | PATCH bloquea cambio de número; Flutter muestra campo no editable en live y no lo envía | Implementar y probar flujo de reverificación y recuperación |
| B10: cron de búsqueda ausente en Vercel | Nuevo `GET /internal/assign-drivers` con secreto y schedule de 30 min | Validar el schedule al desplegar; no se desplegó |
| B11: ranking de conductor desfasado | Recalcula promedio con reseña en una transacción | Ensayo con datos y conflicto concurrente |
| B12: identificadores de otras reservas en disponibilidad | Solo devuelve las asignadas al conductor solicitante | Prueba de permisos con dos conductores |
| B13: suspender último admin | Bloquea autosuspensión y suspensión de cualquier admin activo por ruta genérica | Política explícita de transferencia/revocación de admins; filtros/paginación |
| B14: IDs y fechas/casing | Pipe entero positivo seguro en reservas/vehículos, DTO de fechas `YYYY-MM-DD`, `idReserva` consistente | Normalizar otros controladores/consultas y pruebas HTTP |

## Verificación de este corte

- `npm run build`: correcto.
- `npm test -- --runInBand`: 30 suites, 130 tests correctos, incluido
  el rechazo de orden no activa, el pago tardío y los dos casos de
  disponibilidad.
- `npm run test:e2e -- --runInBand`: 2 suites/5 pruebas con DB/Firebase
  simulados, correctas.
- Flutter `test --no-pub`: 118 pruebas correctas (demo y contratos con
  dobles HTTP); `analyze --no-pub`: sin issues.
- `flutter build web --no-pub --dart-define=CARMAN_USE_LIVE_API=true`:
  compilación correcta antes del último ajuste de endpoints del conductor;
  el ajuste pasó `analyze` y prueba de contrato.
- Smoke HTTP real local, servidor compilado temporal con cron deshabilitado
  y cierre al finalizar: registro sin `persona` **400**, job sin secreto
  **403**, ID de vehículo `0` **400**, salud **200**. Las tres nuevas
  rutas de decisión/inicio/fin respondieron **401** sin token. Se desecharon
  los cuerpos de respuesta; no se probó un registro válido.

## Base Flutter de M0 preparada

- `ApiClient`: PUT, descarga PDF autenticada, 401 distinto de 403.
- Una sesión live guardada solo abre paneles tras validar token y releer roles;
  ante 401/403 se borra la sesión local. Sin refresh, un token vencido requiere
  iniciar sesión de nuevo. Sin «recordar sesión», el ID token solo vive
  en memoria del proceso.
- El router evita montar paneles de otro rol por URL directa; la autorización
  real sigue en backend.
- Favoritos y avisos leídos se guardan por cuenta; los controladores de viajes,
  notificaciones, propietario, conductor y administración y el historial de
  pagos se invalidan al cambiar de identidad. La lectura tardía de la
  identidad anterior no debe sobrescribir el panel nuevo. Marcado de avisos
  hace rollback si falla la petición.
- `ApiProfileRepository`: alta conductor usa `{}` y relee perfil; favoritos
  consultan catálogo público; teléfono distinto no se guarda sin verificación.
- Las acciones del repositorio de conductor envían disponibilidad, aceptar,
  rechazar, iniciar y finalizar a los endpoints y DTOs reales; prueba de
  contrato con cliente HTTP simulado. **El resumen live del conductor aún
  consulta una ruta inexistente** y no permite usar estas acciones desde
  el panel real. Tampoco hay flujo visual de inicio/fin sin conductor. La
  pantalla live deja de atribuir ganancias ficticias al cerrar un servicio.
- No se añadieron librerías ni se rediseñaron pantallas.

### Política de ciclo de vida acordada

El usuario eligió: **si hay conductor asignado, él inicia/finaliza; si no,
lo hace el cliente**. Se exige un anticipo aprobado de al menos 50 % del
total de la orden para iniciar y el total aprobado para finalizar. El inicio
solo se admite dentro del intervalo programado en hora de Colombia; el saldo
puede pagarse con la reserva `EnCurso` incluso después del fin previsto,
evitando un cierre imposible cuando el servicio se retrasa. La acción
rechaza a terceros con 404 y estados incorrectos con 400. Las pruebas de
concurrencia/entrega reales siguen pendientes.

El usuario confirmó que **no dispone todavía de base de ensayo aislada**.
En consecuencia, no se hicieron escrituras autenticadas de negocio ni se
validó el checkout con una cuenta real.

## Qué falta para cerrar M0

1. Reconciliar las migraciones de una **base de ensayo**, nunca ejecutar
   `db:migrate` sobre `carmandb`.
2. Probar con cuentas y fixtures autorizados: activación, login real,
   titularidad multirrol, reservas simultáneas, pago Sandbox y PDF.
3. Diseñar/implementar renovación segura de sesión; actualmente falla cerrada
   en recarga cuando el ID token está vencido.
4. Terminar estados/capacidades en mappers y ensayar explícitamente logout,
   cambios de cuenta y peticiones en vuelo de **todos** los providers; se
   reforzaron los controladores privados principales, no se certificó todo.
   Sustituir los resúmenes live de conductor y administración que todavía
   consultan rutas sin implementación antes de habilitar esos paneles.
5. Resolver protocolo de cambio de teléfono y workflow admin; añadir
   timestamps reales de entrega/devolución si el producto los requiere.
   Las transiciones y pagos ya siguen la política acordada en código,
   pero falta probarlos realmente para declarar M0 completo.

**No se desplegó, no se aplicaron migraciones, no se escribieron filas reales
de negocio y no se exportaron datos privados.**
