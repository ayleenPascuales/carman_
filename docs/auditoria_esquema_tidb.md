# Auditoría de estructura TiDB (preparación, sin cambios en la base)

Fuente: **solo** los 20 archivos `descarga_tidb/*-schema.sql` actualizados.
No se leyeron archivos con filas ni se consultó la instancia de producción.
Una exportación de estructura no demuestra que todos los datos actuales estén
completos o que Firebase/textbee entreguen mensajes. El export se excluye de
Git y de Vercel.

## Tabla por tabla

| Tabla | Relación con la aplicación y estado |
| --- | --- |
| `persona` | Registro, perfil, autenticación y administración usan las columnas actuales. `email` no es UNIQUE; el registro comprueba duplicados y el login resuelve por `uidFirebase`, que puede ser NULL en cuentas antiguas. No vincularlas automáticamente. `direccion` es nullable; `fotoPerfil` es NOT NULL y el alta sin avatar almacena cadena vacía, no una URL inventada. |
| `cliente` | Rol 1:1 por `idPersona`; inserción y consulta compatibles. |
| `conductor` | Rol 1:1; disponibilidad y calificación existen; las rutas de servicios/viajes aún faltan. |
| `propietario` | Rol 1:1; alta y consulta de vehículos compatibles. |
| `administrador` | Rol 1:1 con estado propio; control de acceso compatible. |
| `licencia` | Única por persona y número; los estados usados respetan el CHECK del export. El perfil devuelve `licenciaEstado` con vencimiento efectivo y Flutter no marca licencias como aprobadas por tener un rol. El backend guarda `Vigente` al ingresar una fecha futura: **esto no certifica revisión documental**. |
| `punto_autorizado` | Tiene `ciudad` nullable, coordenadas obligatorias y `activo`. La API selecciona sus columnas reales y permite filtrar por ciudad; Flutter en modo API ya consulta el endpoint, sin inventar distancia o tarifa de entrega. |
| `vehiculo` | Las consultas y sus dos rutas de inserción usan columnas existentes; `precioPorDia` ya se puede guardar/actualizar. Es nullable: sin tarifa la UI no debe tratarlo como disponible. Ciudad se obtiene del punto de recogida si existe. No hay `precioHora`, combustible, transmisión ni política de cancelación en esta tabla. |
| `estado_tecnico_vehiculo` | La revisión técnica administrativa inserta columnas existentes y el kilometraje respeta su CHECK. |
| `phone_verification` | Coincide estructuralmente con `backend/migrations/002_phone_verification.sql`: hashes binarios, vencimiento, contador y clave primaria por teléfono. No depende de una FK; necesita configuración Firebase/textbee para funcionar. |
| `reserva` | Tabla, claves y estados existen; controlador sin endpoints operativos de reserva. |
| `contrato_alquiler` | Relaciona reserva, cliente, vehículo, propietario y conductor; no hay flujo de firma implementado. |
| `orden_de_pago` | Relación única por reserva; no hay ruta de emisión. |
| `pago` | Referencias de orden, método y Wompi; no hay cobro ni webhook implementados. |
| `metodo_pago` | Catálogo en TiDB; el endpoint de métodos de pago del frontend no existe en Nest. |
| `notificacion` | Claves de persona, reserva y pago; no hay rutas operativas. |
| `calificacion` | CHECK exige calificar vehículo **o** conductor y puntuación de 1 a 5; no hay ruta operativa. |
| `ruta` | Relación por reserva y coordenadas; no hay rutas operativas. |
| `telemetria` | Relación por vehículo; no hay ingestión/consulta implementada. |
| `documento` | Guarda contenido binario; no hay servicio de subida/lectura ni almacenamiento de imágenes integrado. |

Las consultas SQL activas de auth, personas, puntos, vehículos y administración
se contrastaron con las columnas de estos archivos. La migración
`001_initial.sql` es histórica para bases vacías y **no** reproduce este
esquema; no modificarla ni ejecutar `db:migrate` sobre `carmandb` porque el
migrador verifica checksums. `002_phone_verification.sql` tampoco debe
reaplicarse si la tabla ya existe.

## Datos y decisiones pendientes antes de producción completa

- Los puntos sin `ciudad` no aparecen al filtrar por ciudad. No inferirla de
  coordenadas ni rellenarla con valores de ejemplo.
- `vehiculo.precioPorDia` puede ser NULL; no inventar tarifas ni disponibilidad.
  La tarifa horaria y otros atributos visuales del frontend tampoco se
  pueden deducir del esquema. Se requiere definir su persistencia y reglas.
- La pantalla de alta de vehículos aún no selecciona IDs reales de puntos ni
  sube fotos/tarjeta de propiedad. El repositorio en modo API **impide enviar
  marcadores ficticios**; falta decidir dónde almacenar archivos y conectar
  esos campos de la UI antes de habilitar el alta real.
- El registro Flutter de conductor tampoco tiene subida de foto de licencia:
  en modo API se bloquea antes de enviar una URL ficticia. El registro inicial
  de propietario exige al menos un vehículo y esta pantalla no lo recoge.
  Hace falta diseñar ambos formularios y el alojamiento de documentos.
- El formulario independiente de licencias también queda bloqueado en modo API:
  no tiene subida segura y no debe aprobar documentos con el temporizador de
  demostración. La revisión documental real necesita un proceso propio; no
  se debe interpretar `Vigente` como aprobación humana.
- La pantalla de vehículo afirma que la nueva alta está «en revisión», pero
  el default real de `vehiculo.estado` es `Activo` y no existe una aprobación
  general de vehículos; la revisión técnica es otro proceso. Definir el
  estado y la autorización de activación antes de admitir altas reales.
- El esquema permite `uidFirebase` NULL y correos duplicados anteriores:
  revisar la vinculación de identidades caso por caso, sin añadir índices
  UNIQUE ni actualizar cuentas en bloque sin auditar los datos.
- `persona.usuario` sí es UNIQUE. El formulario actual deriva el usuario del
  fragmento anterior a `@` del correo: dos direcciones distintas con el mismo
  fragmento pueden chocar. Antes de abrir el registro general, definir un
  nombre de usuario propio o una generación con verificación de colisiones.
- Reservas, pagos, contratos, documentos y otros módulos vacíos requieren
  reglas de negocio, autorizaciones y pruebas; **las tablas no los activan**.
- La ruta de catálogo `/vehiculos/catalogo` no existe en NestJS y
  la captura actualmente `GET /vehiculos/:id` (sin sesión devuelve 401);
  esta ruta de detalle solo devuelve vehículos del propietario autenticado.
  Por eso el catálogo público, los favoritos de otros propietarios y el flujo
  completo de búsqueda no funcionan aún en modo API.
- `/api/health` solo prueba conectividad. Las pruebas automatizadas usan
  datos simulados; no certifican el esquema de la instancia actual ni
  entregas reales de Firebase/textbee.

Si se necesita una comprobación **solo de cantidades**, sin exponer personas
ni filas, un operador puede ejecutar de forma voluntaria en la base correcta:

```sql
SELECT COUNT(*) AS puntos_sin_ciudad
FROM punto_autorizado WHERE activo = 1 AND (ciudad IS NULL OR TRIM(ciudad) = '');
SELECT COUNT(*) AS vehiculos_sin_tarifa
FROM vehiculo WHERE precioPorDia IS NULL OR precioPorDia <= 0;
SELECT COUNT(*) AS cuentas_sin_uid
FROM persona WHERE uidFirebase IS NULL;
SELECT COUNT(*) AS correos_repetidos
FROM (SELECT LOWER(email) FROM persona GROUP BY LOWER(email) HAVING COUNT(*) > 1) AS grupos;
```

No se ejecutaron estas consultas en producción ni se modificó la base. Para
desplegar, primero revisar el build y las pruebas en entorno aislado, decidir
si se aceptan las funcionalidades aún bloqueadas, comprobar los puntos con
ciudad y los flujos de auth con cuentas de prueba, y obtener autorización
expresa para cambiar producción.
