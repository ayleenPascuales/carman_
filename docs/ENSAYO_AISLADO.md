# Pruebas locales sin tocar `carmandb`

El ensayo SQL usa `backend/test/infra/docker-compose.yml`: MySQL 8.4
escucha **solo** en `127.0.0.1:3307`, en la base `carman_ensayo`.
No reutilizar el archivo `backend/.env`: en este equipo apunta a
`carmandb`. Guardar las contraseñas aleatorias y `backend.env` fuera del
repositorio (en esta sesión, `/tmp/opencode/carman-ensayo/`, con permisos
restrictivos). Docker Desktop debe estar iniciado.

`backend.env` debe incluir `DB_HOST=127.0.0.1`, `DB_PORT=3307`,
`DB_USER=carman_ensayo`, `DB_NAME=carman_ensayo`, `DB_PASSWORD` con
la misma contraseña del contenedor y `DB_SSL_MODE=DISABLED`. Esta última
opción **se rechaza** fuera de una base local cuyo nombre comience por
`carman_ensayo` o `carman_test`; la conexión habitual mantiene TLS.
El archivo privado `compose.env` define `CARMAN_TEST_MYSQL_PASSWORD`
y `CARMAN_TEST_MYSQL_ROOT_PASSWORD`. No subirlos, mostrarlos en logs
ni copiar datos personales para poblar el entorno.

En un shell con Docker disponible:

```sh
docker compose --env-file /tmp/opencode/carman-ensayo/compose.env \
  -f backend/test/infra/docker-compose.yml up -d
cd backend
npm run build
node --env-file=/tmp/opencode/carman-ensayo/backend.env scripts/migrate.cjs
CARMAN_ISOLATED_DB_TEST=1 \
  node --env-file=/tmp/opencode/carman-ensayo/backend.env \
  --experimental-vm-modules ./node_modules/jest/bin/jest.js \
  --config ./test/jest-e2e.json --runInBand \
  --runTestsByPath test/isolated-db.e2e-spec.ts
```

Las migraciones `001_initial.sql`, `002_phone_verification.sql` y
`002_z_complete_baseline.sql` completan las **20 tablas de negocio** de
una base nueva. `003_ubicacion_compartida.sql` es optativa y el migrador
la omite a menos que exista una decisión explícita de retención y la
variable `CARMAN_ENABLE_LOCATION_MIGRATION=true`. El migrador rechaza
siempre el nombre `carmandb` y no acepta una base preexistente sin
historial de migraciones. No aplicar este esquema nuevo a la base viva.

La prueba HTTP usa SQL auténtico y filas ficticias `example.invalid`,
que limpia al finalizar; sustituye **solo** el verificador de token.
Comprueba tablas, 401/403, filtros, catálogo, solapes de disponibilidad,
titularidad de vehículo, licencia obligatoria y carreras de reserva,
conflictos entre administradores,
suspensión/reactivación y el informe técnico. **No** prueba registro,
correo, acceso de usuarios Firebase, entrega de documentos, Wompi
Sandbox ni recorrido completo desde Flutter. Para eso hace falta un
proyecto Firebase de ensayo y cuentas de prueba autorizadas, más la
integración Sandbox real. Un contenedor local por sí solo no justifica
promover M0–M5 a producción.
