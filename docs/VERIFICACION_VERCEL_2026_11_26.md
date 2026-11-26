# Verificación Vercel — 26 de noviembre de 2026

## Vista previa de los cambios locales

- Despliegue **Preview**, no producción:
  `dpl_3pszQKstG1zBGFLArxvyyASiXT4v` en
  `https://carman-p6r2xmm4e-proyecto-carman.vercel.app`.
  Vercel informó `READY`; la raíz web respondió HTTP 200 al consultarla
  con autorización del proyecto. La vista previa conserva autenticación
  de Vercel y no es un ensayo integral.
- `/api/health` y `/api/admin/resumen` respondieron HTTP **500**
  (`FUNCTION_INVOCATION_FAILED`). Los logs confirman que falta
  `FIREBASE_PROJECT_ID` en Preview. La lista de variables remotas también
  muestra que DB y Firebase solo están configurados en Production. No
  se copiaron claves de Production a Preview ni se ejecutaron escrituras
  en `carmandb`.
- La CLI `vercel curl` creó cuatro excepciones automáticas de protección;
  se revocaron las tres que no estaban asociadas a
  `VERCEL_AUTOMATION_BYPASS_SECRET`. La API de Vercel **rechazó revocar la
  última** por exigir que permanezca una excepción vinculada a esa
  variable. La protección con autenticación sigue activa; revisar y
  retirar manualmente esa excepción desde el panel de Vercel si es
  posible. No se publica ni conserva aquí el valor de la excepción.

## Producción existente (lectura, no nuevo despliegue)

En `https://carmanapp.vercel.app/` el corte previo respondió: salud
HTTP 200 (`database: ok`), catálogo HTTP 200 con lista vacía y
`/api/admin/resumen` HTTP 404 porque M5 **todavía no estaba desplegado**.
Estos códigos no prueban login, reservas, pagos, revisión de vehículo ni
permisos con usuarios reales.

**Decisión de este corte de Preview:** no promover esa instancia con API
HTTP 500 ni etiquetar M0–M5 como completados. Los pendientes siguen en
[CONTINUAR_DESARROLLO.md](CONTINUAR_DESARROLLO.md).

## Publicación posterior a Production por autorización explícita

Se ejecutó un **build nuevo** con las variables de Production, sin promover
la instancia Preview fallida. Despliegue `dpl_85wj6E7PaFpnzL124qFpUyvkr6Ny`,
`READY`, alias `https://carmanapp.vercel.app/` confirmado.
Smoke externo después de publicar:

- Web `/`: HTTP 200. `GET /api/health`: HTTP 200, `status: ok`,
  `database: ok`. `GET /api/vehiculos/catalogo`: HTTP 200, contrato
  `vehiculos` válido, sin vehículos publicados en la página consultada.
- Sin token: `/api/admin/resumen`, `/api/admin/usuarios`,
  `/api/reservas/conductor/servicios`, `/api/pagos/historial` y
  `/api/vehiculos/mis-vehiculos` devolvieron HTTP 401.
- Build backend, 156 pruebas unitarias, 11 HTTP con dependencias simuladas,
  6 HTTP contra MySQL local aislado, 131 pruebas Flutter demo y 36
  contratos Flutter live con dobles; `flutter analyze --no-pub` sin issues.
  Las seis variables locales de Wompi Sandbox pasaron la validación de
  formato y la clave pública fue reconocida por el merchant Sandbox
  mediante GET; los valores **remotos** de Production siguen ocultos
  y no se ensayó un pago.

**No se ejecutó ninguna migración ni escritura de prueba en `carmandb`.**
La publicación no certifica sesiones Firebase, documentos, flujo de pagos
o recorridos completos entre roles. M0–M5 siguen **parciales**.
