# Contrato API · Carman Frontend ↔ NestJS

Este documento distingue rutas **implementadas** de contratos **previstos pero no disponibles**. Flutter centraliza sus rutas en `lib/data/remote/api_endpoints.dart`; que una ruta aparezca allí no significa que NestJS la exponga. El mapeo está en `lib/data/remote/api_mappers.dart` y en los modelos. El flujo completo sigue disponible solo en modo demo.

## Activación

```bash
flutter run \
  --dart-define=CARMAN_USE_LIVE_API=true \
  --dart-define=CARMAN_API_URL=http://localhost:3000
```

- Base URL por defecto: `http://localhost:3000`.
- Autenticación: `Authorization: Bearer <Firebase idToken>`.
- Fechas: ISO 8601 (`2026-11-24T10:00:00`).
- Importes: números decimales; el esquema de TiDB no fija una moneda.
- Respuestas de error sugeridas: `{ "statusCode": 400, "message": "..." }`.

## 1. Autenticación y personas

### `POST /auth/login`
```json
{ "identificador": "alex.rivera@carman.es", "contrasena": "Carman123" }
```
Respuesta esperada:
```json
{
  "uid": "firebase-uid",
  "idToken": "eyJ...",
  "refreshToken": "AMz...",
  "expiresIn": "3600"
}
```
El frontend usa `idToken` en el resto de peticiones.

### `GET /personas/perfil`
Usa el token. Respuesta compatible:
```json
{
  "idPersona": 1,
  "nombre": "Alex",
  "apellido": "Rivera",
  "email": "alex.rivera@carman.es",
  "telefono": "+573001234567",
  "ciudad": "Cartagena",
  "documento": "1020304050",
  "fotoPerfil": "https://...",
  "fechaHoraRegistro": "2025-03-12T00:00:00",
  "licenciaEstado": "Vigente",
  "roles": { "cliente": true, "conductor": false, "propietario": true }
}
```

### `POST /personas/registro`
```json
{
  "persona": {
    "documento": "1020304050",
    "nombre": "María",
    "apellido": "Gómez",
    "email": "maria@example.com",
    "usuario": "maria",
    "contrasena": "Carman123",
    "telefono": "+573000000000",
    "fechaNacimiento": "1994-05-20",
    "ciudad": "Medellín",
    "direccion": "Dirección opcional"
  },
  "roles": "Cliente"
}
```
`direccion` y `fotoPerfil` son opcionales en la petición. Una licencia requiere
un documento real alojado de forma segura: el frontend en modo API **no** envía
una URL ficticia y todavía no tiene subida de fotos de licencia. El rol
`Propietario` exige además al menos un vehículo válido en el mismo registro;
ese formulario aún no recoge dichos datos. `usuario` es UNIQUE en TiDB: el
formulario lo deriva hoy del prefijo del correo, por lo que registros con
prefijos iguales pueden chocar aunque los correos sean diferentes.

### `PATCH /personas/perfil`
```json
{ "nombre": "Alex", "apellido": "Rivera", "telefono": "+57...", "ciudad": "Cartagena" }
```

### `POST /personas/roles`
Ruta implementada. `{"roles":"Propietario"}` sin `vehiculos` falla: el
backend exige al menos un vehículo válido y puntos activos en el mismo POST.
El formulario Flutter en modo API aún no aporta esos datos y lo bloquea.

### `POST /personas/licencia`
Ruta implementada en NestJS, pero Flutter en modo API **bloquea el formulario**
hasta integrar subida segura y revisión de documentos. El backend registra
`Vigente` por fecha futura: no equivale a validación documental.
```json
{
  "numeroDocumento": "LIC-123",
  "fechaExpiracion": "2030-01-01",
  "tipoLicencia": "B",
  "fotoLicencia": "https://example.com/documento-autorizado.jpg"
}
```

> **Subida de imágenes:** algunas pantallas seleccionan imágenes con `image_picker`,
> pero no existe almacenamiento seguro ni un endpoint de archivos. Antes de
> registrar licencias/vehículos reales hay que integrar subida protegida y
> guardar solo URLs verificadas; no usar documentos de ejemplo.

## 2. Vehículos

### `GET /puntos-autorizados`
Ruta implementada y pública. Parámetro opcional `ciudad` (máximo 50 caracteres);
devuelve **un arreglo** de puntos activos con `idPunto`, `nombre`, `ciudad`
(puede ser NULL), `direccion`, `latitud` y `longitud`. Los DECIMAL de TiDB
pueden llegar como texto. El esquema no incluye distancia al usuario ni coste
de entrega; Flutter en modo API no los inventa. No confundir este endpoint con
los puntos de prueba del modo demo.

### `GET /vehiculos/catalogo`
**Ruta futura: NestJS todavía no la implementa.** La petición coincide hoy con
la ruta protegida `GET /vehiculos/:idVehiculo`: sin sesión responde 401 y
con sesión tampoco devuelve un catálogo. El ejemplo siguiente es una aspiración del producto,
**no** una respuesta que se haya verificado contra TiDB:
Query parameters que puede enviar el frontend:
`ciudad, categoria, modalidad, fechaInicio, fechaFin, precioMaximo, transmision, combustible, plazasMinimas, aperturaMovil, cancelacionGratis, orden, texto`.

Respuesta:
```json
{
  "vehiculos": [
    {
      "idVehiculo": 10,
      "marca": "Tesla",
      "modelo": "Model Y",
      "anio": 2023,
      "tipoVehiculo": "Eléctricos",
      "capacidad": 5,
      "precioHora": 18,
      "precioDia": 75,
      "rating": 4.98,
      "viajes": 46,
      "anfitrion": "Elena Valdés",
      "ubicacion": "Bocagrande",
      "ciudad": "Cartagena",
      "fotos": ["https://...", "https://..."],
      "autonomiaKm": 480,
      "aceleracion": 4.8,
      "maletero": 854,
      "traccion": "Dual Motor AWD",
      "descripcion": "SUV eléctrico...",
      "etiqueta": "Etiqueta 0",
      "aperturaMovil": true,
      "cancelacionGratis": true,
      "puntoRecogida": {
        "id": 3,
        "nombre": "Bocagrande · Hotel Estelar",
        "ciudad": "Cartagena",
        "direccion": "Calle 6 # 6-56",
        "distancia": 0.8,
        "gratis": true
      }
    }
  ]
}
```
El frontend también acepta los nombres en español/inglés que reconoce `Vehicle.fromJson` (`id`, `brand`, `model`, `category`, `photos`, etc.).

### `GET /vehiculos/:id`
Token requerido y solo para vehículos del propietario autenticado. Hoy devuelve
el objeto directamente, con las columnas de `vehiculo` y la ciudad/nombre del
punto de recogida si existe. **No es el endpoint público del catálogo**.

### `GET /vehiculos/mis-vehiculos`
Token requerido. Lista de vehículos del propietario.

### `POST /vehiculos`
Token requerido; crea un vehículo del propietario. El backend espera:
```json
{
  "marca": "Tesla",
  "modelo": "Model Y",
  "anio": 2023,
  "placa": "CAR-482",
  "capacidad": 5,
  "tipoVehiculo": "SUVs",
  "precioPorDia": 75,
  "descripcion": "...",
  "idPuntoRecogida": 7,
  "idPuntoEntrega": 8,
  "fotos": ["https://example.com/imagen-real.jpg"],
  "tarjetaPropiedad": "https://example.com/documento-real.jpg"
}
```

Los IDs y URLs del ejemplo **no deben usarse como datos reales**. `precioPorDia`
es opcional en el esquema, pero sin tarifa no se debe ofrecer el vehículo como
disponible. `precioHora`, combustible, transmisión, ciudad y ubicación escrita
no se almacenan en `vehiculo`; la ciudad se obtiene del punto asociado. La
respuesta de POST solo confirma `idVehiculo` y un mensaje; el cliente consulta
después `GET /vehiculos/:id`. El formulario Flutter actual carece de selección
de puntos y subida de fotos/documentos: en modo API no enviará marcadores
ficticios y no completará el alta hasta integrar esos campos. **Los atributos
avanzados del catálogo mostrado arriba son todavía un contrato futuro**.

## 3. Reservas

**Rutas futuras.** NestJS no ofrece todavía reserva, cobro ni disponibilidad
por fecha. Los ejemplos siguientes son el contrato previsto, no rutas probadas.

### `GET /reservas/mias`
Token requerido. Respuesta:
```json
{ "reservas": [ { "...": "ver objeto Reservation" } ] }
```

### Objeto Reservation
```json
{
  "idReserva": 55,
  "codigo": "CRMN-4821",
  "estado": "Confirmada",
  "fechaInicioServicio": "2026-11-24T10:00:00",
  "fechaFinServicio": "2026-11-27T10:00:00",
  "modalidad": "daily",
  "vehiculo": { "...": "objeto Vehicle" },
  "puntoRecogida": {
    "id": 3,
    "nombre": "Bocagrande · Hotel Estelar",
    "direccion": "Calle 6 # 6-56",
    "ciudad": "Cartagena",
    "distancia": 0.8,
    "gratis": true
  },
  "seguro": "premium",
  "seguroNombre": "Allianz Premium",
  "metodoPago": { "marca": "Mastercard", "ultimos4": "4242" },
  "desglose": {
    "unidades": 3,
    "tarifa": 75,
    "alquiler": 225,
    "diasSeguro": 3,
    "seguro": 54,
    "servicio": 24,
    "impuestos": 63.63,
    "descuento": 0,
    "deposito": 150
  },
  "codigoLlave": "CRMN-7310",
  "resenado": false,
  "fechaHoraReserva": "2026-11-20T09:00:00"
}
```
Estados reconocidos: `Pendiente`, `Confirmada`, `Activa`, `Completada`, `Cancelada`, `Rechazada`, `Expirada` (también sus equivalentes en inglés).

### `POST /reservas`
```json
{
  "idVehiculo": 10,
  "fechaInicio": "2026-11-24T10:00:00",
  "fechaFin": "2026-11-27T10:00:00",
  "modalidad": "daily",
  "idPuntoRecogida": 3,
  "idPuntoEntrega": 3,
  "seguro": "premium",
  "metodoPagoId": "pm-apple",
  "metodoPago": "Apple Pay · Mastercard •••• 4242"
}
```

### `PATCH /reservas/:id/cancelar`
Sin body. Devuelve `{ "reserva": { ... } }` o al menos `{ "ok": true }`.

### `POST /reservas/:id/calificacion`
```json
{ "puntuacion": 5, "comentario": "Excelente" }
```

## 4. Notificaciones

**Rutas futuras;** las tablas existen pero NestJS no expone estos endpoints.

### `GET /notificaciones`
```json
{
  "notificaciones": [
    {
      "idNotificacion": 12,
      "tipo": "reserva",
      "titulo": "Reserva confirmada",
      "mensaje": "Tesla Model Y · 24–27 nov",
      "leida": false,
      "fechaHora": "2026-11-20T09:00:00",
      "rutaAccion": "/trips"
    }
  ]
}
```

### `PATCH /notificaciones/leidas`
Sin body. Marca todas como leídas.

### `PATCH /notificaciones/:id/leida`
Sin body.

## 5. Panel de propietario

**`GET /propietario/resumen` no está implementado.** Flutter intenta primero
esa ruta y puede usar `GET /vehiculos/mis-vehiculos` como alternativa, sin
métricas de ingresos ni reservas reales.

### `GET /propietario/resumen`
```json
{
  "estadisticas": {
    "vehiculos": 2,
    "activos": 2,
    "ingresosMes": 2480,
    "reservasPendientes": 3,
    "ocupacion": 0.78,
    "ingresosMesAnterior": 2210
  },
  "vehiculos": [
    {
      "id": 1,
      "estado": "Alquilado",
      "proximoMantenimiento": "2026-12-20",
      "ingresoMes": 1480,
      "viajesMes": 12,
      "documentosAlDia": true,
      "vehiculo": { "...": "objeto Vehicle" }
    }
  ]
}
```
Si este endpoint no existe todavía, el frontend cae automáticamente a `GET /vehiculos/mis-vehiculos` y calcula las métricas disponibles.

## 6. Pagos

Los endpoints de pago están reservados en `ApiEndpoints`:

- `GET /pagos/metodos`
- `POST /pagos/metodos`
- `PATCH /pagos/metodos/:id`
- `POST /pagos`

La app actual usa métodos de demostración y una tarjeta de prueba. **No se debe
enviar el número completo de tarjeta al backend propio**: la pasarela debe
tokenizar los datos y procesar pagos confirmados. El esquema actual prevé
referencias de Wompi, pero no existe integración ni webhook: hay que elegir y
validar una pasarela antes de habilitar pagos reales.


## 8. Panel de conductor

El acceso requiere `roles.conductor = true`. El panel usa estas rutas:

### `GET /conductor/resumen`
```json
{
  "disponibilidad": "disponible",
  "estadisticas": {
    "viajesHoy": 4,
    "gananciasHoy": 86,
    "gananciasSemana": 412,
    "rating": 4.92,
    "aceptacion": 0.96,
    "horasConectado": 5.5,
    "viajesTotales": 328
  },
  "servicios": [
    {
      "idServicio": 1001,
      "estado": "En camino",
      "cliente": {
        "nombre": "Laura Pérez",
        "telefono": "+57 301 555 0192",
        "fotoPerfil": "https://..."
      },
      "vehiculo": { "...": "objeto Vehicle" },
      "origen": "Centro Histórico · Plaza de la Aduana",
      "destino": "Hotel Estelar · Bocagrande",
      "fechaHora": "2026-11-24T15:30:00",
      "distanciaKm": 4.2,
      "duracionMin": 18,
      "ganancia": 18,
      "notas": "El cliente está en la recepción."
    }
  ]
}
```
Estados de servicio reconocidos: `Nuevo`, `Aceptado`, `En camino`, `En curso`, `Completado`, `Cancelado`.

### `PATCH /conductor/disponibilidad`
```json
{ "disponible": true }
```

### Acciones de servicio
- `PATCH /conductor/servicios/:id/aceptar`
- `PATCH /conductor/servicios/:id/iniciar`
- `PATCH /conductor/servicios/:id/finalizar`
- `PATCH /conductor/servicios/:id/rechazar`

Sin body. El frontend actualiza el estado y las ganancias localmente para respuesta inmediata; al recargar, `GET /conductor/resumen` debe devolver el estado real.

## 9. Panel de administración

Requiere que `GET /personas/perfil` incluya `roles.administrador = true` y que el backend aplique `AdminGuard` en todas estas rutas.

### `GET /admin/resumen`
```json
{
  "estadisticas": {
    "usuarios": 1248,
    "conductores": 86,
    "vehiculos": 312,
    "pendientes": 3,
    "reservasHoy": 47,
    "ingresosMes": 12480,
    "crecimiento": 12.8
  },
  "usuarios": [ { "...": "objeto AdminUser" } ],
  "aprobaciones": [ { "...": "objeto AdminApproval" } ]
}
```
Si no existe `/admin/resumen`, el frontend consulta `GET /admin/usuarios` y calcula las métricas disponibles.

### `GET /admin/usuarios`
```json
{
  "usuarios": [
    {
      "idPersona": 1,
      "nombre": "Alex",
      "apellido": "Rivera",
      "email": "alex@carman.es",
      "telefono": "+57 300 123 4567",
      "ciudad": "Cartagena",
      "roles": { "cliente": true, "propietario": true, "administrador": true },
      "estado": "Activo",
      "fechaHoraRegistro": "2025-01-10T00:00:00",
      "viajes": 14,
      "emailVerificado": true
    }
  ]
}
```

### `PATCH /admin/usuarios/:id/estado`
```json
{ "estado": "Suspendido" }
```

### `GET /admin/aprobaciones`
```json
{
  "aprobaciones": [
    {
      "idAprobacion": 7,
      "tipo": "licencia",
      "solicitante": "María Gómez",
      "email": "maria@example.com",
      "titulo": "Licencia de conducir",
      "detalle": "Categoría B · vence 20/08/2030",
      "estado": "Pendiente",
      "fechaSolicitud": "2026-11-20T10:00:00"
    }
  ]
}
```

### `PATCH /admin/aprobaciones/:id`
```json
{ "estado": "Aprobada" }
```
Valores: `Aprobada`, `Rechazada`.

## 10. Roles

- `Cliente`: catálogo y reservas.
- `Propietario`: panel de propietario y publicación de vehículos.
- `Conductor`: panel operativo de servicios.
- `Administrador`: panel de administración.

La cuenta demo incluye los cuatro roles para facilitar la revisión. En producción, cada rol debe venir del backend y las rutas de conductor/administración deben protegerse también en el servidor.

## 11. Dónde adaptar el contrato

| Necesidad | Archivo |
| --- | --- |
| Cambiar una ruta | `lib/data/remote/api_endpoints.dart` |
| Cambiar nombres de campos | `lib/data/remote/api_mappers.dart` |
| Cambiar filtros del catálogo | `lib/data/models/vehicle_query.dart` |
| Cambiar la URL base / modo demo | `lib/core/config/app_config.dart` |
| Conectar un nuevo repositorio | `lib/providers.dart` |

Con esto el frontend puede alternar entre demo y API sin tocar las pantallas.
