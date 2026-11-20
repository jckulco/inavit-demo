# 05 · Netezza SaaS (Azure): almacén `INAVIT_DW`

El esquema `INAVIT_DW` tiene 11 tablas y 6 vistas, con unos 5.5 millones de filas. Las reglas de negocio viven en
las vistas; Cognos lee las vistas, nunca las tablas.

## Crear el esquema

En DBeaver, conectado a la base de tu instancia (puerto 5480), en este orden:

1. [`netezza/00_schema.sql`](../netezza/00_schema.sql): `CREATE SCHEMA INAVIT_DW`.
2. [`netezza/01_tables.sql`](../netezza/01_tables.sql): las 11 tablas con tipos, `NOT NULL` y `DISTRIBUTE ON`.
3. Carga de datos: con DataStage ([`04-datastage.md`](04-datastage.md)) o desde CSV (abajo).
4. [`netezza/02_views.sql`](../netezza/02_views.sql): las 6 vistas. `V_PRECALIFICADOS` va antes de `V_PRECALIFICADOS_DASH`.
5. [`netezza/90_validacion.sql`](../netezza/90_validacion.sql): compara contra las cifras de referencia.

Los scripts de tablas y vistas se reconstruyeron del catálogo (`_V_RELATION_COLUMN`, `_V_TABLE_DIST_MAP`,
`_V_VIEW`) y se probaron el 18 de noviembre de 2026 en un esquema limpio (`INAVIT_TEST`) sin errores.
Las llaves primarias no se incluyen porque Netezza no las impone.

## Tablas

| Tabla | Filas | Distribución | Origen |
|---|---|---|---|
| `CREDITO_INTEGRADO` | 104,871 | `NUM_CREDITO` | HANA ⋈ Db2, depurado |
| `DIM_ENTIDAD` | 32 | `RANDOM` | HANA |
| `DIM_PATRON` | 15,000 | `REGISTRO_PATRONAL` | Db2 |
| `DIM_PERIODO` | 14 | `RANDOM` | Calculada |
| `DIM_PRODUCTO` | 5 | `RANDOM` | HANA |
| `DIM_TRABAJADOR` | 251,272 | `NSS` | Db2 |
| `DQ_CREDITO_HUERFANO` | 444 | `NUM_CREDITO` | Créditos sin trabajador |
| `FACT_APORTACION` | 2,639,227 | `NSS` | Db2 |
| `FACT_COBRANZA` | 25,472 | `NUM_CREDITO` | HANA |
| `FACT_PAGO` | 2,216,653 | `NUM_CREDITO` | HANA |
| `FACT_SUBCUENTA` | 251,272 | `NSS` | Db2 |

## Vistas y reglas de negocio

| Vista | Qué responde |
|---|---|
| `V_FACT_APORTACION` | Aportaciones con patrón, sector, entidad, región y días después de la fecha límite |
| `V_FACT_CREDITO` | Créditos con producto, entidad, patrón omiso, `ES_MOROSO` y `RANGO_MORA` |
| `V_FACT_PAGO` | Pagos con su periodo mensual y bimestral |
| `V_PATRON_OMISO` | Patrones con `ES_OMISO = 1`: omiso oculto (sigue activo), trabajadores afectados, créditos y saldo en riesgo |
| `V_PRECALIFICADOS` | Trabajadores precalificados para crédito, con rangos de saldo y antigüedad |
| `V_PRECALIFICADOS_DASH` | `SELECT` directo sobre `V_PRECALIFICADOS`; **no se borra**: el módulo de Cognos depende de ella |

**Regla de precalificación** (`V_PRECALIFICADOS`): trabajador sin crédito en `CREDITO_INTEGRADO`, `ESTATUS = 'A'`,
`ES_DUPLICADO_CURP = 0`, 24 bimestres cotizados o más y saldo de subcuenta de 150,000 pesos o más.
Resultado: 25,583 de 250,022 trabajadores (10.2%). Cambiar un umbral es editar la vista y recargar el módulo
en Cognos.

**Morosidad:** `ES_MOROSO = 1` cuando `ESTATUS_CREDITO` es `MOROSO` o `CARTERA_VENCIDA`.

**Omiso oculto:** patrón con `ES_OMISO = 1` y `ESTATUS = 'A'` en el padrón.

## Restaurar desde CSV

Los 11 CSV se exportaron con DBeaver (*Export Data* → CSV, con encabezado), uno por tabla, por ejemplo
`DIM_PATRON_202611181038.csv`. Tamaños de referencia: `FACT_APORTACION` 258 MB, `FACT_PAGO` 200 MB,
`DIM_TRABAJADOR` 36 MB, `CREDITO_INTEGRADO` 25 MB.

Para cargarlos: en DBeaver, clic derecho sobre cada tabla vacía → *Import Data* → CSV, con la primera fila como
encabezado y el mapeo de columnas por nombre. Después corre `02_views.sql` y `90_validacion.sql`.
Así se probó la restauración del proyecto original.

Los CSV no se suben a git (pesan ~540 MB). Guárdalos fuera del repositorio o como *release asset* privado.

## Consultas de la demo

[`netezza/91_consultas_demo.sql`](../netezza/91_consultas_demo.sql) tiene las consultas de los actos 4 y 5 del guion.

## Si la instancia no responde

En el proyecto original una falla de la instancia dejó consultas colgadas y DBeaver no pudo cancelarlas
("Cancel operation timed out"). Lo que funcionó:

1. Cerrar DBeaver a la fuerza (en macOS: Cmd+Opción+Esc). Al cortarse la conexión, Netezza cierra la sesión.
2. Revisar el estado de la instancia (pausada o con falla) en la consola de IBM Cloud, desde donde se administra la instancia de Netezza SaaS en Azure.
3. Reabrir y probar con `SELECT 1;` antes de cualquier consulta pesada.
4. Si quedan sesiones viejas: `SELECT ID, USERNAME, DBNAME, STATUS, CONNTIME, COMMAND FROM _V_SESSION;`.
