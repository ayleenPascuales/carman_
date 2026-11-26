# Avance fase 4 — M4 conductor: servicios y disponibilidad

**Estado: parcial; publicado posteriormente sin certificación integral.** Depende de los pendientes de
[M0](AVANCE_FASE4_M0.md), [M1](AVANCE_FASE4_M1.md) y
[M2](AVANCE_FASE4_M2.md). Alcance: [PLAN_PANELES_POR_ROL.md](PLAN_PANELES_POR_ROL.md).

## Conectado

- Nuevo `GET /reservas/conductor/servicios?pagina=N`, autenticado y limitado
  a reservas cuyo `idConductor` corresponde a la persona del token. Página
  de 20 con `hayMas`; el SQL limita con enteros validados y prioriza servicios
  vigentes. Incluye disponibilidad y vigencia de licencia, puntos de origen/
  destino, fechas/horas y vehículo; no expone teléfono, documentos, placa,
  cobros ni ganancias del cliente. La cuenta sin rol no ve un panel vacío.
- Flutter carga el endpoint mediante el repositorio existente; las acciones
  conservan PATCH de respuesta del conductor, inicio/finalización y
  disponibilidad. Usa **ID de reserva**; `Pendiente` + respuesta `Pendiente`
  es oferta, `Confirmada` + `Aceptada` es aceptada, `EnCurso` está en curso y
  `Finalizada` está terminada. Los estados desconocidos no se convierten en
  nuevas ofertas. Tras mutar se vuelve a consultar el servidor; un resultado
  no confirmable no se muestra como éxito ni se reintenta automáticamente.
- Historial cargable por páginas con filtros finalizados/cancelados y detalle
  en el sheet existente; enlace a la pantalla de licencia. No se presentan
  como liquidaciones los importes del cliente, ni se anuncia una llamada
  telefónica si el backend no proporciona contacto verificable.
- La aceptación requiere disponibilidad y licencia válida hasta el último
  día del servicio. Los estados del backend impiden aceptar dos veces,
  responder sin asignación o ejecutar transiciones fuera de orden; rechazar
  conserva la reserva del cliente y deja la reasignación al servicio existente.
  Iniciar requiere anticipo aprobado y horario válido; finalizar requiere
  saldo aprobado. El GPS compartido sigue siendo opcional.

## Límites / verificación

- El historial lista solo reservas **todavía asignadas**. Las rechazadas que
  se reasignaron dejan de ser visibles: falta un registro específico de
  asignaciones históricas si se desea mostrar los rechazos del conductor.
- No hay resumen financiero, liquidación ni valoración propia verificable;
  las barras de ingresos del modo demo no se muestran en modo API. La
  paginación por desplazamiento puede variar si se reasignan reservas entre
  páginas; la deduplicación por ID en Flutter no equivale a un cursor estable.
- Pruebas con dobles validan rol, titularidad, contrato y reintentos.
  **No** se ensayó el flujo completo con cuentas autorizadas y una base de
  ensayo aislada; no declarar M4 cerrado ni usar `carmandb` para migraciones.
  NestJS compila; 31 suites/148 pruebas backend y 2 suites/10 pruebas HTTP
  simuladas pasaron. En Flutter pasaron 131 pruebas de la suite demo
  (3 pruebas live omitidas sin `--dart-define`) y 3 pruebas de contrato live
  con `--dart-define=CARMAN_USE_LIVE_API=true`. El build web live compiló;
  `flutter analyze --no-pub` final terminó **sin issues**.
