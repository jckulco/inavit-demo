# 04 · DataStage: extracción, calidad e integración

DataStage corre como motor remoto (DataStage as a Service Anywhere) en Docker sobre VM2 (RHEL 9.8), con el plano
de control en IBM Cloud. Hace dos trabajos: copia SAP HANA a staging, y después integra las dos fuentes de staging, aplica las
reglas de calidad y carga Netezza.

> **Estado de esta sección.** Los flujos del proyecto original no están exportados en este repositorio. Lo que
> sigue describe qué hace cada flujo, deducido del modelo de Netezza y de sus banderas de calidad. Para que el
> repositorio sea reproducible sin reconstruir nada, exporta los flujos y guárdalos en `datastage/export/`
> (instrucciones al final).

## Conexiones

| Conexión | Tipo | Host:puerto | Base / esquema | Usuario |
|---|---|---|---|---|
| HANA | SAP HANA (JDBC `ngdbc.jar`) | VM1:39041 | tenant `HXE`, esquema `INAVIT_FIN` | `INAVIT_DS` (solo lectura) |
| Staging SQL Server | Microsoft SQL Server | VM3:1433 (o el endpoint de ngrok) | `INAVIT_STG.INAVIT_APO` | login de solo lectura |
| Staging PostgreSQL | PostgreSQL | VM3:5432 | `inavit_stg.hana_raw` | el de tu instalación |
| Netezza | IBM Netezza Performance Server for DataStage | `<instancia>`:5480 | `<base>.INAVIT_DW` | usuario de la instancia |

URL de HANA: `jdbc:sap://<vm1>:39041/?databaseName=HXE`. El detalle del driver y del campo *Jar uris* está en
el repositorio [`jckulco/sap-hana-datastage-lab`](https://github.com/jckulco/sap-hana-datastage-lab).

## Flujo 1 · HANA → PostgreSQL `hana_raw`

Copia sin transformar las cinco tablas de `INAVIT_FIN` a `hana_raw` (DDL en
[`staging/postgresql/01_hana_raw.sql`](../staging/postgresql/01_hana_raw.sql)). Se ejecuta en lote: la cartera
cambia en cortes y no necesita captura por log (IIDR, además, no soporta HANA como origen).

Validación: [`staging/postgresql/90_validacion.sql`](../staging/postgresql/90_validacion.sql), con los mismos
conteos que HANA.

## Flujo 2 · Integración y carga a Netezza `INAVIT_DW`

| Tabla destino | Origen | Reglas visibles en el modelo |
|---|---|---|
| `DIM_ENTIDAD` | `hana_raw.cat_entidad` | Copia + `FECHA_CARGA` |
| `DIM_PRODUCTO` | `hana_raw.cat_producto_credito` | Copia + `FECHA_CARGA` |
| `DIM_PERIODO` | Calculada | 14 bimestres con fechas de inicio, fin y límite de pago |
| `DIM_PATRON` | `INAVIT_STG.PATRON` + aportaciones | Razón social normalizada (`DQ_RAZON_CORREGIDA`), `MUNICIPIO` en mayúsculas, `ES_OMISO`, `ULTIMO_PERIODO_APORTACION` |
| `DIM_TRABAJADOR` | `INAVIT_STG.TRABAJADOR` | `CURP_VALIDA`, `DQ_NOMBRE_CORREGIDO`, `DQ_FECHA_NAC_INVALIDA`, `ES_DUPLICADO_CURP` |
| `FACT_SUBCUENTA` | `INAVIT_STG.SUBCUENTA_VIVIENDA` | Copia + `FECHA_CARGA` |
| `FACT_APORTACION` | `INAVIT_STG.APORTACION` | `DQ_DIAS_INVALIDOS` (días > 62), `DQ_MONTO_CERO` |
| `CREDITO_INTEGRADO` | `hana_raw.credito` ⋈ `TRABAJADOR` | NSS con `TRIM`, CURP corregida, estatus normalizado, nombre corregido o discrepante, fecha de nacimiento inválida; agrega sexo, fecha de nacimiento, SDI y estatus del trabajador |
| `DQ_CREDITO_HUERFANO` | `hana_raw.credito` sin trabajador | Rechazos con `NSS_ORIGINAL`, `NSS_LIMPIO` y `MOTIVO` |
| `FACT_PAGO` | `hana_raw.pago` | Copia + `FECHA_CARGA` |
| `FACT_COBRANZA` | `hana_raw.cobranza` | Copia + `FECHA_CARGA` |

Cuadre que debe cumplirse siempre: créditos de HANA = `CREDITO_INTEGRADO` + `DQ_CREDITO_HUERFANO`
(105,315 = 104,871 + 444).

Comportamiento a conservar:

- **Las aportaciones nuevas se agregan sin borrar las existentes.** Así es como las 10 filas de la demo en vivo
  llegan a `FACT_APORTACION`.
- **Los borrados no se propagan a Netezza.** El reset de la demo en vivo borra también en Netezza
  ([`demo-live/`](../demo-live/)).
- El `MUNICIPIO` de `DIM_PATRON` queda en mayúsculas aunque en Db2 esté en formato título
  (`Jiutepec` → `JIUTEPEC`). Es esperado.

## Alternativa sin DataStage: restaurar desde CSV

Si solo necesitas el almacén para la demo, puedes cargar los CSV exportados de Netezza
(ver [`05-netezza.md`](05-netezza.md), sección *Restaurar desde CSV*). Pierdes el acto 4 en vivo
(el flujo corriendo), pero las cifras quedan idénticas.

## Exportar los flujos al repositorio

En el proyecto de DataStage, selecciona los dos flujos y sus conexiones y expórtalos como ZIP
(menú *Export* / *Exportar a ZIP* de la lista de activos del proyecto; el nombre exacto cambia por versión).
Guarda el archivo en `datastage/export/` y anota en [`datastage/README.md`](../datastage/README.md):

- el nombre de cada flujo y de cada conexión,
- cuánto tarda la carga a Netezza (para el guion),
- si las credenciales quedaron fuera del export (normalmente sí: hay que recapturarlas al importar).

Para importar en un proyecto nuevo: *Import* del ZIP, recaptura las credenciales de las cuatro conexiones,
corre el flujo 1 y después el flujo 2.
