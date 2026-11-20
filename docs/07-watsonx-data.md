# 07 · watsonx.data Developer Edition (VM4): historia en Iceberg y vistas federadas

El lakehouse guarda la **historia** en tablas Iceberg sobre MinIO; Netezza conserva la parte **caliente**
(2026) y los maestros. Dos vistas federadas en Presto unen ambas fuentes como una sola tabla.
Netezza no se modifica: sigue teniendo toda la historia, así que las cifras de Cognos no cambian.

## Instalación y acceso

watsonx.data Developer Edition se instaló con [`jckulco/wxd-remote-access`](https://github.com/jckulco/wxd-remote-access)
(KIND + Helm, namespace `wxd`, repo en `/opt/repos/wxd-remote-access`).

| Servicio | Servicio de Kubernetes | Puerto en VM4 / laptop |
|---|---|---|
| Consola | `lhconsole-ui-svc:443` | 6443 → `https://localhost:6443/` |
| Consola de MinIO | `ibm-lh-minio-svc:9001` | 9001 → `http://localhost:9001/` |
| API S3 de MinIO | `ibm-lh-minio-svc:9000` | 9000 |
| Presto | `ibm-lh-presto-svc:8443` | 8443 |
| Hive Metastore (thrift, sin web) | `ibm-lh-mds-thrift-svc:8381` | opcional |

1. En VM4 (root): `bash watsonx-data/start_forwards.sh` (o el original en `/opt/repos/wxd-remote-access/`).
2. En la laptop: `ssh -fN inavit-vm4` ([`config/ssh_config.example`](../config/ssh_config.example)).

Si la consola redirige a un hostname `*.internal.cloudapp.net` que no carga, agrega en la laptop
`127.0.0.1 <ese-hostname>` a `/etc/hosts`.

Catálogos y buckets de fábrica: `hive_data` (bucket `hive-bucket`), `iceberg_data` (`iceberg-bucket`),
`wxd_system_data` (`wxd-system`), más `tpch` y `tpcds`. Motor: `presto-01` (Presto Java).

## 1. Subir los CSV a MinIO

Los CSV son los exportados de Netezza ([`05-netezza.md`](05-netezza.md)). Se suben **cinco**, cada uno en su
propia carpeta (una tabla externa lee una carpeta completa):

```
hive-bucket/inavit_raw/dim_entidad/DIM_ENTIDAD_*.csv
hive-bucket/inavit_raw/dim_periodo/DIM_PERIODO_*.csv
hive-bucket/inavit_raw/dim_patron/DIM_PATRON_*.csv
hive-bucket/inavit_raw/fact_aportacion/FACT_APORTACION_*.csv
hive-bucket/inavit_raw/fact_pago/FACT_PAGO_*.csv
```

Con la consola web de MinIO: entra a `hive-bucket`, crea la ruta y arrastra el archivo. El cliente `mc` ya no se
descarga de `dl.min.io` (responde 410); la alternativa por línea de comandos es `rclone` con un remoto S3 que
apunte a `http://localhost:9000`.

## 2. Carga histórica

En *Query workspace*, motor `presto-01`, ejecuta [`watsonx-data/01_carga_historica.sql`](../watsonx-data/01_carga_historica.sql)
**una sentencia a la vez y en orden**:

1. Esquemas `hive_data.inavit_raw` e `iceberg_data.inavit_dw`, cada uno con `location` explícita.
2. Cinco tablas externas Hive sobre los CSV (`format = 'CSV'`, todas las columnas `VARCHAR`).
3. Prueba de lectura: 33 / 15 / 15,001 filas en `dim_entidad`, `dim_periodo` y `dim_patron`
   (el encabezado cuenta como una fila).
4. Dimensiones a Iceberg con `CTAS`, descartando la fila de encabezado.
5. Hechos a Iceberg con `CTAS`, particionados por `periodo` y con los cortes:
   `fact_aportacion` con `periodo <= '202506'` y `fact_pago` con `periodo <= '202512'`.

## 3. Registrar Netezza y crear las vistas federadas

1. *Infrastructure manager → Add component → Data sources → IBM Netezza* (no la tarjeta de *Engines*).
2. Base, host, puerto 5480, usuario y contraseña de la instancia. *Test connection* debe dar *Successful*.
3. Marca *Associate catalog* con el nombre **`netezza_inavit`** y *Create*.
4. Asocia el catálogo al motor `presto-01` (el motor se reinicia unos minutos).
5. Ejecuta [`watsonx-data/02_vistas_federadas.sql`](../watsonx-data/02_vistas_federadas.sql).

Engine o Data source: un *engine* es un motor que ejecuta consultas (en la edición Developer solo está Spark);
un *data source* crea un catálogo que Presto consulta y cruza con Iceberg. Para federar se usa *data source*.

## 4. Validar

[`watsonx-data/90_validacion.sql`](../watsonx-data/90_validacion.sql). Validado el 19 de noviembre de 2026:

| Vista | Fuente | Filas | Suma |
|---|---|---|---|
| `v_fact_aportacion` | lakehouse | 1,713,809 | 2,642,127,743.50 |
| `v_fact_aportacion` | netezza | 925,418 | 1,476,389,605.18 |
| `v_fact_aportacion` | **total = Netezza completo** | **2,639,227** | **4,118,517,348.68** |
| `v_fact_pago` | lakehouse | 1,219,692 | 4,625,913,931.47 |
| `v_fact_pago` | netezza | 996,961 | 4,334,898,289.68 |
| `v_fact_pago` | **total = Netezza completo** | **2,216,653** | **8,960,812,221.15** |

## Errores que ya se resolvieron (y ya están corregidos en los scripts)

| Error | Causa | Solución |
|---|---|---|
| `Schema creation requires an explicit location` | Los esquemas de este catálogo no tienen ubicación por defecto | `CREATE SCHEMA ... WITH (location = 's3a://<bucket>/<ruta>')` |
| `Catalog 'hive_data' does not support table property 'skip_header_line_count'` | El conector Hive de esta versión no la soporta | Se quita; el encabezado se descarta en cada `CTAS` con `WHERE lower(<col>) <> '<col>'` |
| `Type not supported for Iceberg: smallint` | Iceberg no tiene `SMALLINT` | `INTEGER` |
| Tablas externas vacías o mezcladas | CSV sueltos en `inavit_raw/` | Una carpeta por tabla |

## Rendimiento

- Las consultas solo sobre Iceberg responden en menos de un segundo.
- Las federadas tardan de 15 a 20 segundos: Presto lee Netezza por JDBC a través de internet.
- `SHOW TABLES` sobre `netezza_inavit` llegó a tardar 82 segundos la primera vez.
- Antes de una demo, corre la consulta federada una vez y filtra por `periodo` para que cada consulta toque una
  sola fuente cuando sea posible.

## Opcional: descargar la historia de Netezza

El paso natural de la narrativa sería borrar de Netezza los periodos ya copiados al lakehouse. **No se hizo**,
porque cambia las cifras del tablero de Cognos, que lee solo Netezza. Decídelo después de revisar el tablero.
