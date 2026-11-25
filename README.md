# CARMAN

Plataforma web y móvil para el alquiler de vehículos entre particulares, con llave digital, verificación de conductores y reservas protegidas.

## Descripción

Carman conecta a clientes, conductores y propietarios de vehículos. Permite explorar el catálogo, consultar disponibilidad, reservar, pagar, abrir el coche desde el móvil y gestionar viajes. El frontend está construido con Flutter (Android, iOS y web) sobre el design system de Carman.

## Tecnologías principales

- **Frontend:** Flutter 3.50+, Dart 3.14+, Riverpod y GoRouter.
- **Backend:** Node.js y NestJS.
- **Base de datos:** MySQL.
- **Autenticación y servicios complementarios:** Firebase.
- **Inteligencia artificial:** integración planificada.

## Estructura del proyecto

- `backend/`: API y lógica del servidor (NestJS).
- `frontend/`: aplicación Flutter para web y móvil. **Incluye 29 pantallas funcionales, paneles de cliente, propietario, conductor y administración, diseño responsive para móvil/tablet/web y datos demo.**
- `docs/`: documentación técnica.
- `infrastructure/`: configuraciones de infraestructura y despliegue.

## Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

La aplicación arranca en modo demo, sin backend. Credenciales de prueba:

- Correo: `alex.rivera@carman.es`
- Contraseña: `Carman123`
- Código SMS: `582301`

Consulta la [documentación del frontend](frontend/readme.md) para arquitectura, flujo de pantallas, tests y guía de integración. El contrato JSON para backend está en [frontend/docs/api_contract.md](frontend/docs/api_contract.md).

### Vista previa

![Home de Carman](frontend/docs/screenshots/home.png)

## Backend

El backend ya implementa autenticación con Firebase, registro por roles, perfil y gestión de vehículos. Los módulos de reservas, pagos, notificaciones, rutas y calificaciones exponen controladores vacíos que deben completarse antes de conectar el frontend en modo API.

```bash
cd backend
npm install
npm run start:dev
```

`CARMAN_USE_LIVE_API=true` y `CARMAN_API_URL=http://localhost:3000` activan el consumo de la API real desde Flutter.

## Despliegue web + API en un proyecto Vercel

El [`vercel.json`](vercel.json) de la raíz usa [Vercel Services (beta)](https://vercel.com/docs/services): Flutter Web se compila como sitio estático y NestJS como función. Ambos comparten **un proyecto y un dominio**. En Vercel, `/` (incluidos enlaces directos como `/admin`) sirve Flutter, mientras `/api/health`, `/api/auth/...` y las demás rutas `/api/...` llegan a NestJS sin cambiar sus rutas internas.

1. Antes de desplegar, rotar las credenciales TiDB y Firebase Admin que se compartieron anteriormente. Revisar el esquema de `carmandb` y la tabla OTP propuesta en `backend/migrations/002_phone_verification.sql`; **no ejecutar `db:migrate` sobre esa base existente**.
2. Subir los cambios al repositorio y crear **un único proyecto Vercel** con **Root Directory = raíz del repositorio** (no `backend` ni `frontend`). Usar Node.js 22/24; no sobrescribir los comandos de compilación ni la carpeta de salida definidos por servicio en `vercel.json`. El build web instala un Flutter 3.50.1 fijado y verificado, y activa `CARMAN_USE_LIVE_API=true`; puede tardar varios minutos.
3. En **Settings → Environment Variables**, configurar solo para el servidor `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL_CA`, `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_CLIENT_EMAIL` + `FIREBASE_PRIVATE_KEY` (o `FIREBASE_SERVICE_ACCOUNT_JSON`), `TEXTBEE_API_KEY`, `SMS_OTP_SECRET`, `CRON_SECRET` y `CORS_ORIGINS=https://<dominio-del-proyecto>`. Revisar `backend/.env.example` y habilitar Production/Preview según corresponda. Guardar las claves en Vercel, **no en Git ni en `dart-define`**.
4. Verificar `/`, `/admin`, un archivo real como `/main.dart.js`, `/api/health` y que `/api/internal/inactive-accounts` sin `CRON_SECRET` devuelva 403. Después, iniciar sesión con la cuenta de prueba existente (no registrarla de nuevo) y probar Firebase/textbee con sus proveedores configurados. `/api/health` solo comprueba conexión a TiDB: no confirma tablas, correo ni SMS.

Flutter Web usa automáticamente el dominio actual más `/api`, tanto en producción como en previews. Android/iOS se compilan y distribuyen **por separado**: para conectarlos a este proyecto, usar `--dart-define=CARMAN_USE_LIVE_API=true --dart-define=CARMAN_API_URL=https://<dominio-del-proyecto>/api`. Vercel no ejecuta las apps nativas. Varias rutas de reservas, pagos y otros módulos **aún no están implementadas** en el backend; desplegar la web en modo API no hace funcionales esos flujos. Detalles de configuración y límites: [`backend/readme.md`](backend/readme.md).

## Estado

Frontend completo y navegable en modo demo. Backend en desarrollo: reservas, pagos y notificaciones pendientes. La integración en vivo está preparada a nivel de repositorios.
