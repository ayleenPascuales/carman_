# M6 (primer corte): favoritos sincronizados

**Estado: parcial y desplegado; no certificado con sesión real.**
M6 tiene otras capacidades opcionales que siguen pendientes; este corte
implementa solamente favoritos.

## Contrato y arquitectura

- `GET /vehiculos/favoritos?pagina=N`: autenticado, página de 20 IDs y
  `hayMas`; la identidad se obtiene del token. `POST` y `DELETE` sobre
  `/vehiculos/favoritos/:idVehiculo`: operaciones idempotentes. Solo se puede
  añadir un vehículo publicado que aparezca en el catálogo; eliminar no
  requiere que siga publicado.
- Nueva tabla `favorito` con clave primaria por persona y vehículo, claves
  foráneas y marca de tiempo. Migración optativa `004_favoritos.sql`.
  El servicio devuelve HTTP 503 si falta la tabla: no presenta una lista
  vacía engañosa ni guarda favoritos solo en memoria cuando se usa la API.
- `FavoritesController` sigue siendo el estado de los widgets actuales.
  En modo demo utiliza el almacenamiento local por cuenta existente; en
  modo API obtiene los IDs del backend y consulta los detalles mediante
  el endpoint público de catálogo. Las operaciones son confirmadas antes
  de actualizar los corazones; los errores permiten reintentar. Al cambiar
  de cuenta se descartan respuestas antiguas.
- No se migra automáticamente el almacenamiento local de demo a cuentas
  reales: hacerlo podría mezclar datos falsos con preferencias reales.

## Comprobación y despliegue

En `carman_ensayo` se aplicó únicamente la migración `004` y se comprobaron
autenticación, aislamiento por cuenta, idempotencia, validación y catálogo
publicado mediante siete pruebas HTTP con SQL real; los datos ficticios
fueron limpiados por la suite. Los tests del repositorio Flutter comprueban
la paginación, token, códigos de error y validación de IDs.

El usuario confirmó que ejecutó la creación de `favorito` en TiDB; no se
inspeccionó su esquema ni se ejecutó `migrate.cjs` sobre `carmandb` desde
este proyecto. El despliegue Production
`dpl_69RE9SpsRwSKkhQuJ8oG8eDCs9b6` quedó `READY` en
`https://carmanapp.vercel.app/`. El smoke externo confirmó web, salud y
catálogo HTTP 200, y favoritos sin token HTTP 401. Esta comprobación **no**
demuestra que el usuario de base de datos de la API pueda leer o escribir
en `favorito`: falta probar el recorrido autenticado con una cuenta de
ensayo autorizada. No se ejecutaron escrituras de prueba en `carmandb`.
No se han certificado recorridos completos de M6.
