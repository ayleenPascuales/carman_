# API Carman (NestJS + TiDB Cloud + Firebase Authentication)

La API implementa **auth, personas, puntos autorizados, vehículos y administración**. La infraestructura está preparada para TiDB Cloud **compatible con MySQL** mediante `mysql2` y TLS, credenciales Firebase por variables de entorno y despliegue nativo de NestJS en Vercel. **No es todavía una aplicación completa de reservas/pagos**: esos módulos y varias rutas del contrato Flutter están sin implementar.

## Alta y activación (Firebase + textbee)

El registro crea primero el usuario Firebase y la fila en TiDB. Solo cuando la transacción queda confirmada solicita **un correo de bienvenida/activación** con la plantilla `VERIFY_EMAIL` de Firebase Authentication. Para evitar que registros anónimos agoten la cuota de SMS de la SIM, **el código SMS se solicita después de pulsar el enlace del correo**. El backend genera el código, almacena solo un HMAC en TiDB y envía el SMS mediante textbee desde un Android tuyo. El código caduca en 10 minutos, admite 5 intentos; máximo 5 envíos por número y hora y 60 segundos entre envíos. La respuesta del registro incluye `correoEnviado` (Firebase aceptó la solicitud, no confirmación de recepción) y `smsEnviado: false`; si el correo falla después del commit, la cuenta ya existe: **no repetir el registro**. Solo las cuentas **nuevas** se marcan para exigir ambas verificaciones; las antiguas no se bloquean retroactivamente.

1. En **Firebase Console → Authentication → Templates → Email address verification**, personalizar asunto y texto para dar la bienvenida e indicar que el enlace activa la cuenta; revisar los dominios autorizados y habilitar Email/Password. La API utiliza Identity Toolkit (`signInWithPassword` y `sendOobCode`, idioma español); la cuenta Firebase Admin no es el remitente de correo. Tras abrir el enlace, pulsar **«Ya activé mi correo»** en Flutter.
2. En [textbee](https://textbee.dev/docs/getting-started/registering-a-device), crear cuenta, confirmar tu correo, instalar la app en **tu Android con SIM activa**, registrar el dispositivo, concederle permiso de SMS y mantenerlo encendido/con acceso a Internet; marcarlo como predeterminado. Crear una API key en **Dashboard → API Keys** y ponerla en `TEXTBEE_API_KEY` del backend, **nunca en Flutter/Git/chat**. El [plan gratuito](https://textbee.dev/pricing) permite 1 Android, 50 SMS/día y 300/mes; tu operador puede cobrar por los SMS de la SIM. Una respuesta `200` de textbee significa **en cola**, no entrega al destinatario; consulta el historial de envío del Android/textbee si no llega.
3. Generar `SMS_OTP_SECRET` con `openssl rand -hex 32` y conservarlo en `.env` local y como secreto de Vercel; si se rota, los códigos anteriores dejarán de servir. **Nueva tabla requerida:** revisar `migrations/002_phone_verification.sql` y ejecutar **solo ese CREATE TABLE** manualmente en tu base existente, tras confirmar que no hay tabla con ese nombre. No ejecutar `db:migrate` sobre `carmandb`. No se ha aplicado ningún cambio a la base real desde este proyecto.
4. El teléfono debe estar en formato **E.164** (`+573001234567`). Tras confirmar el correo, el frontend llama a `/auth/telefono/reenviar` y a `/auth/telefono/confirmar` con `{ "codigo": "123456" }`, usando `Authorization: Bearer <idToken>`. `GET /auth/verificacion` indica `correoVerificado`, `telefonoVerificado` y `activada`. Los reenvíos requieren sesión y nunca aceptan un número arbitrario. Para producción se recomienda además un CAPTCHA/límite por IP antes de crear usuarios, y comprobar las condiciones del operador para uso de SMS automatizados.
5. **Tu `carmandb` ya contiene tablas distintas de la migración inicial.** Hay que comparar `SHOW CREATE TABLE persona;` y `SHOW CREATE TABLE cliente;` (más roles si procede) con las consultas actuales antes de probar nuevos registros. `/health` solo valida conexión.

En Flutter Web, activar modo API con `--dart-define=CARMAN_USE_LIVE_API=true`; en el proyecto único de Vercel, el cliente usa automáticamente el origen de la página más `/api`. En desarrollo local hay que pasar además `--dart-define=CARMAN_API_URL=http://localhost:3000`. El código demo `582301` solo funciona en modo demo y **no** valida SMS reales. Si no configuras `TEXTBEE_API_KEY` y `SMS_OTP_SECRET`, o falta la tabla de verificación, el registro nuevo responde `503` **antes** de crear un usuario; los usuarios existentes pueden iniciar sesión.

**Si el registro ya devolvió `correoEnviado: false`, la cuenta ya existe.** No vuelvas a llamar a `/personas/registro`: corrige la configuración, reinicia Nest, inicia sesión con esa misma cuenta y pulsa **Reenviar correo**. Después de activar el correo, solicita el SMS. La consola del backend registra solo proveedor, operación y estado/código de fallo seguro (no respuestas completas, contraseñas, tokens ni teléfonos). El aviso `fromJSON is deprecated` de una dependencia de Google no demuestra que el correo haya fallado: mira la advertencia `FIREBASE ...` para conocer la operación y el código. Las pruebas automatizadas usan mocks; **no garantizan entrega real de correo/SMS**: se necesita una cuenta de prueba con credenciales Firebase nuevas, correo válido, Android textbee encendido y la tabla nueva para probar el circuito completo.

## Desarrollo local

Requisitos: Node.js 22.22.3+ o 24.15.0+ (mínimos de las herramientas Nest instaladas); una instancia TiDB Cloud **MySQL-compatible** con soporte de claves foráneas (TiDB 8.5+), una base creada y un proyecto Firebase con proveedor **Email/Password** habilitado. La contraseña que se compartió en el chat debe rotarse antes de configurar el servicio.

```bash
cd backend
npm ci
cp .env.example .env
# Completar .env con los datos reales; nunca subirlo al repositorio.
# NO ejecutar db:migrate sobre carmandb: ya tiene tablas.
npm run start:dev
curl http://localhost:3000/health
```

`GET /health` consulta TiDB y responde `{"status":"ok","database":"ok"}`. Si la API no arranca, revisar variables, DNS/TLS y permiso de conexión. **Health verifica conectividad, no la existencia de las tablas**: comprobar registro/login/perfil por separado. El registro de propietario exige `idPuntoRecogida` e `idPuntoEntrega` existentes y activos; `GET /puntos-autorizados` lista los puntos disponibles. Poblar primero `punto_autorizado` con ubicaciones reales, por ejemplo:

```sql
INSERT INTO punto_autorizado (nombre, ciudad, direccion)
VALUES ('Punto centro', 'Bogotá', 'Dirección por definir');
```

Antes de migrar, comprobar con `SHOW TABLES` que la base indicada en `DB_NAME` está vacía. No ejecutar migraciones sobre una base existente sin comparar previamente su esquema con `migrations/001_initial.sql`: el script se niega a adoptar tablas preexistentes sin historial de migraciones. Si ya tienes tablas en TiDB, **no ejecutes `db:migrate`**; se requiere mapear el esquema real a estos servicios. No se ejecutan migraciones automáticamente durante el despliegue ni durante las invocaciones serverless. Si una migración falla a mitad, inspeccionar y corregir manualmente antes de reintentar.

## Configuración

Ver [`.env.example`](.env.example). Copiar **host, puerto, usuario y nombre de base exactamente** desde **Connect → General/MySQL** en TiDB (puerto predeterminado del backend: `4000`, pero manda el panel). Usar una **contraseña nueva**; la anterior fue expuesta en el chat y debe revocarse. Variables obligatorias para nuevas cuentas: `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, credenciales Admin del **mismo proyecto**, `TEXTBEE_API_KEY` y `SMS_OTP_SECRET`. `DB_POOL_SIZE` es 2 por instancia. TLS valida el certificado del servidor: en local, `DB_SSL_CA_PATH=certs/isrgrootx1.pem` lee la CA pública ISRG Root X1 incluida en el repositorio. En Vercel, **no uses la ruta local**: pon el contenido de ese PEM en la variable privada `DB_SSL_CA` (saltos reales o `\n`), que tiene prioridad sobre `DB_SSL_CA_PATH`. Si el servidor no usa una cadena que llegue a ISRG Root X1, usa la CA indicada por el proveedor; esta CA no sustituye la contraseña. Si no defines ninguna CA explícita, Node.js usa sus raíces de confianza. Nunca usar `rejectUnauthorized: false`.

En Vercel usar `FIREBASE_CLIENT_EMAIL` y `FIREBASE_PRIVATE_KEY` (con `\n` escapados), o `FIREBASE_SERVICE_ACCOUNT_JSON` con el JSON completo de la cuenta. Para desarrollo local también se acepta `GOOGLE_APPLICATION_CREDENTIALS` apuntando a un archivo privado; **no** subir JSON ni llaves a Git. La API key es la Web API Key de Firebase para iniciar sesión con correo/contraseña; no es la clave privada. Si restringes esta clave, el backend debe poder llamar a Identity Toolkit desde Vercel (una restricción solo por referrer del navegador bloquearía este login). En desarrollo, sin `CORS_ORIGINS` se permite `localhost` en cualquier puerto; en Vercel se exige un origen HTTPS exacto (por ejemplo, el dominio de producción, sin barra final). Flutter Web y la API están en el mismo origen, también en Preview, así que sus llamadas `/api` no requieren CORS; agregar orígenes adicionales solo para clientes web alojados en otro dominio. Las aplicaciones móviles nativas no requieren configuración CORS.

### Dónde conseguir lo que falta

1. **TiDB Cloud → instancia → Connect → General/MySQL:** comprobar que `DB_HOST`, `DB_PORT`, `DB_USER` y `DB_NAME` pertenecen a la **misma** instancia y que esa base existe. Como la contraseña anterior se compartió, usar **Reset/Generate Password** y guardar la **nueva** solo en `.env` local y en Vercel. Comprobar las reglas de acceso de IP del endpoint público. El certificado `certs/isrgrootx1.pem` es público y solo valida TLS; si el panel proporciona otra CA para este endpoint, usar esa CA en `DB_SSL_CA_PATH` (local) o `DB_SSL_CA` (Vercel).
2. **Firebase Console → Configuración del proyecto → General:** confirmar el *ID del proyecto* y la *Web API Key* del **mismo proyecto**. **Authentication → Sign-in method → Email/Password:** habilitar el proveedor. **Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada:** descargar el JSON de la cuenta de servicio una sola vez y extraer `client_email` y `private_key` para `FIREBASE_CLIENT_EMAIL` y `FIREBASE_PRIVATE_KEY` (o usar el JSON completo en `FIREBASE_SERVICE_ACCOUNT_JSON`). Guardar la clave fuera de Git y nunca enviarla por chat.
3. **Vercel → proyecto Carman → Settings → Environment Variables:** añadir las variables `DB_*` con la nueva contraseña, las variables `FIREBASE_*`, `TEXTBEE_API_KEY`, `SMS_OTP_SECRET` y `DB_SSL_CA` con el PEM. Elegir los entornos Preview/Production que correspondan. `CORS_ORIGINS` puede ser el origen HTTPS exacto de producción (sin barra final); `CRON_SECRET` es un secreto aleatorio propio, por ejemplo generado con `openssl rand -hex 32`. Crear **un único proyecto con la raíz del repositorio** como Root Directory. Tras desplegar, comprobar `/api/health` y luego login/perfil para verificar también Firebase.

## Vercel

1. Usar **un solo proyecto Vercel**, con Root Directory en la raíz del repositorio (no `backend` ni `frontend`) y Node.js 22/24. El [`vercel.json` raíz](../vercel.json) usa [Vercel Services (beta)](https://vercel.com/docs/services): `web` compila Flutter 3.50.1 para el CDN y `api` detecta NestJS desde `backend/src/main.ts`. No configurar otro Build/Output Directory en el panel. El script `frontend/scripts/build-web.sh` descarga el SDK de Flutter fijado y verifica su SHA-256; por ello, el primer build tarda más. Flutter Web se compila **en modo API real**, no demo.
2. Configurar las variables privadas necesarias del backend según `.env.example`, incluidas credenciales rotadas, `DB_SSL_CA` (sin `DB_SSL_CA_PATH`), `CORS_ORIGINS=https://tu-proyecto.vercel.app` y un `CRON_SECRET` aleatorio largo. Seleccionar los entornos Production/Preview adecuados. **Nunca** añadir contraseñas, claves Firebase Admin, textbee ni `SMS_OTP_SECRET` como `dart-define` ni publicarlas en Git.
3. **No ejecutar `db:migrate` sobre `carmandb`: ya contiene tablas.** Comparar el esquema real con las consultas del backend y revisar la tabla OTP `migrations/002_phone_verification.sql` antes de crearla manualmente. Mantener TLS hacia TiDB y situar la función en una región cercana a la base para evitar latencia y exceso de conexiones (`DB_POOL_SIZE` se aplica por instancia).
4. El proyecto publica `/` y rutas de Flutter como `/admin` (con fallback SPA); la API se accede por `/api/health`, `/api/auth/...`, `/api/personas/...`, etc. La regla interna elimina `/api` antes de entregar la petición a NestJS, por lo que en desarrollo local Nest conserva las rutas sin prefijo. El Schedule diario de las 02:00 de Bogotá llama a `GET /api/internal/inactive-accounts` con `Authorization: Bearer <CRON_SECRET>` (Vercel puede aplicar jitter). El cron de NestJS solo trabaja fuera de Vercel.
5. Flutter Web utiliza automáticamente `https://<dominio-del-despliegue>/api`, incluso en previews. Las aplicaciones Android/iOS se distribuyen aparte y se compilan con `--dart-define=CARMAN_USE_LIVE_API=true --dart-define=CARMAN_API_URL=https://<tu-proyecto>.vercel.app/api`. **Activar modo API no implementa las rutas pendientes** de pagos, reservas, etc.

### Comprobaciones rápidas

```bash
curl -i https://tu-proyecto.vercel.app/api/health
curl -i -X POST https://tu-proyecto.vercel.app/api/personas/registro \
  -H 'Content-Type: application/json' \
  -d '{"roles":"Cliente","persona":{"documento":"DOC-UNICO-1","nombre":"Ada","apellido":"Lovelace","email":"usuario@ejemplo.com","usuario":"ada","contrasena":"una_clave_segura_123","telefono":"+573001234567","fechaNacimiento":"1990-01-01","ciudad":"Bogotá","direccion":"Dirección de prueba","fotoPerfil":"https://example.com/avatar.png"}}'
curl -i -X POST https://tu-proyecto.vercel.app/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"identificador":"usuario@ejemplo.com","contrasena":"una_clave_segura_123"}'
# Con el idToken de login:
curl -H "Authorization: Bearer TU_ID_TOKEN" https://tu-proyecto.vercel.app/api/personas/perfil
```

El ejemplo de registro crea datos reales en Firebase y TiDB: usar un correo/documento únicos y **no emplear esta contraseña de muestra en producción**. Si ya se creó una cuenta durante pruebas, **no repetir el registro**: iniciar sesión con esa cuenta. Un login válido requiere una cuenta creada en Firebase Authentication y la fila `persona` asociada a **ese mismo UID** en TiDB (p. ej. por `POST /personas/registro` local o `/api/personas/registro` en Vercel). El guard valida el ID token con Firebase, comprueba estado en TiDB y actualiza actividad. Para habilitar administración, asignar manualmente el rol `administrador` en TiDB a una `persona` verificada, con controles de acceso a la base de datos.

## Alcance pendiente

Los controladores de `reservas`, `pagos`, `notificaciones`, `rutas` y `calificaciones` son esqueletos sin endpoints operativos. El frontend además referencia catálogo, favoritos, paneles y recuperación de contraseña que esta API aún no expone. El cliente en modo API actualmente conserva el ID token de Firebase pero **no renueva los tokens caducados**; esto debe resolverse antes de utilizar sesiones largas y reenvíos tardíos. La migración inicial incluye **solo las tablas de los módulos implementados**; no crea tablas ni pasarela real para esas funciones pendientes. El envío/hosting real de imágenes y pagos también requiere servicios externos y trabajo adicional. Hasta implementar esas rutas y ajustar los payloads, **mantener Flutter en modo demo para el flujo completo**.
