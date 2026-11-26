# Auditoría ejecutada — CARMAN, 26 de noviembre de 2026

## Resultado

**El backend arranca y conecta con TiDB, pero no está validado al 100 %.**
Se reprodujo un error HTTP 500 en registro y un defecto del servicio de
correo. Hay recorridos privados pendientes de pruebas con cuentas de ensayo.

El plan y el inventario completo están en
[`PLAN_PANELES_POR_ROL.md`](PLAN_PANELES_POR_ROL.md).
Este documento registra la **ejecución de esta auditoría**, no un despliegue.

## Entorno y alcance

- Checkout local: rama `boris`, HEAD `32bf073`, con modificaciones locales
  previas. El análisis incluye esos cambios, no solo el commit.
- Backend: Node `24.13.1`, Linux/WSL, código compilado con `npm run build`.
- No se encontró una API escuchando inicialmente. Se levantó temporalmente
  `backend/dist/main.js`, puerto local `3107`, usando la configuración existente
  de `backend/.env`. Los valores de credenciales no se incluyeron en evidencias.
- Se establecieron únicamente para ese proceso: `VERCEL=1`,
  `CORS_ORIGINS=http://localhost:5173`, un `CRON_SECRET` efímero y
  `TRIP_LOCATION_ENABLED=false`. Esto aplica el prefijo `/api` y evita los
  cron en memoria durante la auditoría.
- La primera espera de arranque de unos 20 segundos fue insuficiente; con
  una espera acotada mayor el servidor inició correctamente.
- El servidor temporal se terminó al concluir. No se ejecutaron migraciones,
  creación de cuentas, reservas, cargos, SMS ni mutaciones autenticadas.
- Las consultas de metadatos fueron de solo lectura. Los cuerpos con filas
  del catálogo/puntos no se guardaron ni se publicaron.
- El corte HTTP terminó a las **07:31:47 UTC** del 26 de noviembre.
  No acredita el despliegue Vercel, los dominios productivos ni su CORS.

## Verificaciones automáticas

| Comprobación ejecutada | Resultado | Qué acredita |
|---|---|---|
| `npm run build` en `backend/` | Correcto | Compilación actual del backend |
| `npm test -- --runInBand` | 26 suites, 107 pruebas correctas | Contratos y lógica con dobles de servicios/DB |
| `npm run test:e2e -- --runInBand` | 2 suites, 5 pruebas correctas | Grafo Nest y HTTP con DB/Firebase **simulados** |
| Flutter `analyze --no-pub` | Sin issues | Análisis estático |
| Flutter `test --no-pub --reporter expanded` | 109 pruebas correctas | Widgets, demo, mappers y HTTP simulado |
| Peticiones al proceso real de Nest | 69 casos, 68 con HTTP esperado, 1 discrepancia | Lecturas públicas, validación y rechazo de acceso |

Flutter se ejecutó desde `frontend/` con
`cmd.exe /c C:\\flutter\\bin\\flutter.bat`.
Las pruebas Flutter emplean la configuración por defecto/dobles de los tests;
no equivalen a navegar todos los paneles con cuentas live.
No se recompiló la web ni se hizo una revisión de consola de navegador en
este corte de auditoría.

### Distribución de los 69 casos HTTP

| HTTP observado | Casos |
|---|---:|
| 200 | 9 |
| 204 | 1 |
| 400 | 10 |
| 401 | 44 |
| 403 | 1 |
| 404 | 3 |
| 500 | 1 |

El conteo no incluye intentos de conexión durante el arranque.
**68 respuestas esperadas no significa 68 operaciones de negocio completadas.**

### Casos y observaciones

Los paths de esta tabla llevan `/api` en el proceso auditado.

| Petición / escenario | Observación |
|---|---|
| `GET /` | 200, texto |
| `GET /health` | 200, claves `status`, `database` |
| `GET /health/tablas` | 200; 20/20 nombres de tablas esperadas detectados en metadatos |
| `GET /vehiculos/catalogo` | 200, clave `vehiculos`; catálogo vacío en esta ejecución |
| Catálogo con ciudad sintética sin coincidencias | 200, contrato conservado |
| `GET /puntos-autorizados`, con/sin ciudad sintética | 200, array; no se exportaron puntos |
| Ciudad de 51 caracteres en catálogo/puntos | 400 en ambos |
| ID `abc` en detalle público y ambas consultas de calificaciones | 400 en los tres |
| ID sintético inexistente en detalle público y ambas consultas de calificaciones | 404 en los tres |
| `GET /rutas/vehiculos/0/punto-cercano` | 400 |
| `POST /rutas/vehiculos/0/punto-cercano`, latitud fuera de rango | 400 |
| `POST /auth/login`, cuerpo vacío | 400 |
| Login con correo sintético del dominio `.invalid` y contraseña ficticia | 401; se recorre el intercambio real de login, sin sesión válida |
| `POST /personas/registro`, cuerpo vacío | 400 |
| `POST /personas/registro`, `{"roles":"Cliente"}` | **500**, se esperaba 400 |
| `POST /pagos/wompi/eventos`, `{}` sin firma | 400; no se procesó un pago |
| Cada una de las 42 rutas con `AuthGuard`, sin token | 401 en todas, incluidos POST, PUT, PATCH y DELETE |
| `GET /personas/perfil`, token sintético inválido | 401 |
| `GET /internal/inactive-accounts`, sin secreto | 403; mantenimiento no ejecutado |
| `GET /health`, origen permitido | 200 con `Access-Control-Allow-Origin` esperado |
| `GET /health`, origen no permitido | 200 **sin** esa cabecera; comportamiento CORS esperado |
| `OPTIONS /personas/licencia`, PUT y headers de autenticación | 204 con origen permitido |

El login inválido no certifica la configuración completa de Firebase: el
servicio traduce diversos errores 4xx del proveedor a 401.
No hubo vehículo público disponible para completar con 200 el detalle,
su promedio de reseñas y la cercanía. Esas ramas quedan pendientes.

## Defectos reproducidos

### A. Registro sin objeto `persona`

- Entrada: `POST /api/personas/registro`, JSON `{"roles":"Cliente"}`.
- Resultado: HTTP 500; el DTO debería rechazarla con 400.
- Evidencia: `backend/src/personas/dto/registroInicial.dto.ts:14` tiene
  `ValidateNested`/`Type` sin exigir la existencia del objeto.
  `backend/src/personas/personas.service.ts:42` accede a
  `dto.persona.telefono` inmediatamente.
- Pendiente para fase 4: exigir objeto definido, validar anidados y probar
  ausencia, `null`, array y tipos inválidos antes de cualquier efecto externo.

Reproducción contra un servidor local ya iniciado con prefijo `/api`:

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  -H 'Content-Type: application/json' \
  -d '{"roles":"Cliente"}' \
  http://127.0.0.1:3107/api/personas/registro
```

### B. Doble lectura del cuerpo de Firebase

- `backend/src/auth/verification.service.ts:101` consume `response.json()`.
  En éxito, la línea 109 intenta consumirlo otra vez.
- Se ejecutó el servicio **compilado** `enviarCorreoInicial` con `fetch`
  sustituido por una `Response` nativa de Node, HTTP 200 y contenido sintético.
  No se hizo ninguna llamada de red ni envío de correo.
- Resultado: 503, diagnóstico `FIREBASE signInWithPassword NETWORK_ERROR`,
  una llamada al doble de `fetch`. No llega al envío inicial del enlace.
- La lectura repetida de una `Response` nativa produce
  `TypeError: Body is unusable: Body has already been read`.
- Pendiente para fase 4: consumir una sola vez el cuerpo, devolver ese
  resultado y añadir una prueba con semántica real de `Response`.
  El reenvío puede solicitar el envío al proveedor y aun así devolver error
  al leer la respuesta; debe comprobarse sin fomentar reintentos duplicados.

## Metadatos de base de datos consultados

Se usaron `information_schema.COLUMNS`, `STATISTICS`,
`TABLE_CONSTRAINTS` y `CHECK_CONSTRAINTS`, sin filas de negocio:

- No faltan **nombres de columnas** de las 20 tablas del DDL documental al
  compararlos con los metadatos de la conexión local. Esto no compara todos
  los tipos, valores predeterminados ni restricciones.
- En `calificacion` existen índices únicos sobre
  `(idReserva,idVehiculo)` y `(idReserva,idConductor)`.
- La consulta de `CHECK` no devolvió restricciones para `calificacion`.
  Un primer intento de incluir `ENFORCED` falló con `ER_BAD_FIELD_ERROR`;
  se consultaron después las cláusulas sin ese campo. **No se certifica
  enforcement del XOR ni del rango mediante intentos de escritura.**
- `ubicacion_compartida` no aparece en los metadatos consultados.
- Defaults observados de `vehiculo`: `estado='Activo'` y
  `estado_solicitud_revision='Sin_solicitud'`.
- Este resultado corresponde a la conexión configurada localmente. No se
  asumió que Vercel utiliza exactamente la misma conexión/configuración.

## Qué falta para acreditar el recorrido completo

1. Entorno de ensayo aislado y cuentas controladas de cliente, propietario,
   conductor y administrador, con verificación utilizable.
2. Login exitoso, expiración/renovación, suspensiones y separación entre
   titulares usando tokens válidos.
3. POST/PUT/PATCH/DELETE exitosos con lectura posterior, concurrencia y
   limpieza solo de fixtures identificados del entorno de ensayo.
4. Reserva con y sin conductor, confirmación, anticipo/restante Sandbox,
   webhook firmado e idempotente, inicio/finalización, reseña y PDF.
5. Navegación Flutter live por rol, recarga, enlaces directos, errores de
   consola y revisión visual móvil/escritorio.

Estas comprobaciones quedan preparadas en el plan. **No hubo correcciones
de código ni despliegue en esta auditoría.**
