# CARMAN

Proyecto de aula de alquiler de vehículos entre particulares. Aplicación Flutter (web y cliente móvil), API NestJS, TiDB Cloud, Firebase Authentication, textbee para SMS, Wompi **Sandbox** para pagos y Mapbox Directions opcional para rutas. **La presencia de una pantalla demo no acredita una funcionalidad operativa en la web publicada.**

## Documentos para entrega

| Documento | Archivo |
| --- | --- |
| Guía institucional de referencia (no modificar) | `Guia Proyecto Aulas Semestres 2 al 5 Unicolombo Ver 1.0 .docx` |
| Informe de aula | `Informe Proyecto de Aula - CARMAN.docx` |
| Manual de usuario | `Manual De Usuario - CARMAN.docx` |
| Manual técnico | `Manual Tecnico - CARMAN.docx` |
| Fuentes editables, figuras DEMO, SQL documental y lista de pendientes | [`docs/entrega/README_entrega.md`](docs/entrega/README_entrega.md) |

**No incluir** en la entrega cuentas de prueba, filas exportadas de TiDB, contraseñas, ubicaciones reales ni imágenes de consolas de proveedores. El anexo SQL reconstruye estructura documental, **no** es una migración para la base existente.

## Estado y límites (corte noviembre de 2026)

- Web y API en un proyecto Vercel: <https://carmanapp.vercel.app>. El último registro de comprobaciones públicas documentó 200 en web, salud, catálogo y puntos, y 401 sin sesión en rutas privadas.
- `GET /api/health/tablas` encontró 20 tablas **en metadatos**; no acredita SELECT/INSERT/UPDATE ni la tabla optativa de ubicación.
- Hay rutas implementadas de catálogo, puntos, registro, perfil, reservas, notificaciones, revisión administrativa, órdenes y checkout Wompi **Sandbox**, y rutas viales condicionales a Mapbox. La web live crea reservas **sin realizar pagos**; no hay apertura móvil real ni correo transaccional.
- El registro puede crear cuenta, pero la verificación de correo Firebase falló en producción con 503; no se ha comprobado un alta completa. No crear cuentas repetidamente para revisar documentación.
- La ubicación precisa de viajes solo está prevista para cliente y conductor adultos con consentimiento explícito durante `EnCurso`; requiere aprobación de la tabla `003_ubicacion_compartida.sql` y activación de servidor. **No consta aplicada ni habilitada en producción**. El propietario no ve la ubicación precisa.
- Código local con cambios no confirmados: no asumir que todo lo leído en el árbol local está en el último deploy. Los últimos resultados de tests registrados antes de esta entrega fueron 100 backend y 105 Flutter, con análisis Flutter sin incidencias; no son pruebas E2E de producción.

## Estructura

- `backend/src/`: módulos NestJS; `backend/migrations/`: scripts históricos y opción GPS.
- `frontend/lib/`: interfaz Flutter, repositorios demo/API y pantallas.
- `docs/entrega/`: fuentes Markdown, DOCX generados, imágenes rotuladas y anexo SQL.
- `vercel.json`: composición `web` + `api` y Schedule.

## Ejecución local (sin tocar producción)

```bash
cd backend
npm ci
cp .env.example .env
# Configurar .env en local; NO ejecutar db:migrate contra carmandb.
npm run start:dev
```

```bash
cd frontend
flutter pub get
flutter run -d chrome  # modo demo predeterminado
# Para conectar una API local configurada:
flutter run -d chrome --dart-define=CARMAN_USE_LIVE_API=true \
  --dart-define=CARMAN_API_URL=http://localhost:3000
```

El build web en `frontend/scripts/build-web.sh` activa el modo API en Vercel; Android/iOS se compilan y distribuyen por separado. La URL API puede ser pública; **ningún secreto** debe ir en `dart-define` o en el navegador. Consultar el [manual técnico](docs/entrega/Manual_Tecnico_CARMAN.md) y los archivos `.env.example` antes de configurar servicios.
