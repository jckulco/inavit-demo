-- ============================================================================
-- INAVIT: carga de HISTORIA a watsonx.data (Presto -> Iceberg)
-- Narrativa: lakehouse = historia; Netezza = parte caliente (2026) + maestros
-- Corte: FACT_APORTACION periodo <= '202506' (bimestral, YYYY0B)
--        FACT_PAGO       periodo <= '202512' (mensual,   YYYYMM)
-- Ejecutar en Query workspace, motor presto-01, una sentencia a la vez (en orden)
-- Requisito: CSV en s3a://hive-bucket/inavit_raw/<tabla>/  (una carpeta por tabla)
-- ============================================================================

-- ---------- 1. ESQUEMAS ----------
CREATE SCHEMA IF NOT EXISTS hive_data.inavit_raw
  WITH (location = 's3a://hive-bucket/inavit_raw/');
CREATE SCHEMA IF NOT EXISTS iceberg_data.inavit_dw
  WITH (location = 's3a://iceberg-bucket/inavit_dw');

-- ---------- 2. TABLAS EXTERNAS (CSV, todo VARCHAR) ----------
CREATE TABLE IF NOT EXISTS hive_data.inavit_raw.dim_entidad (
  clave VARCHAR, nombre VARCHAR, region VARCHAR, fecha_carga VARCHAR
) WITH (format = 'CSV',
        external_location = 's3a://hive-bucket/inavit_raw/dim_entidad/');

CREATE TABLE IF NOT EXISTS hive_data.inavit_raw.dim_periodo (
  periodo VARCHAR, anio VARCHAR, bimestre VARCHAR, fecha_inicio VARCHAR,
  fecha_fin VARCHAR, fecha_limite_pago VARCHAR
) WITH (format = 'CSV',
        external_location = 's3a://hive-bucket/inavit_raw/dim_periodo/');

CREATE TABLE IF NOT EXISTS hive_data.inavit_raw.dim_patron (
  registro_patronal VARCHAR, rfc VARCHAR, razon_social VARCHAR, sector VARCHAR,
  tamanio VARCHAR, entidad_clave VARCHAR, municipio VARCHAR, codigo_postal VARCHAR,
  fecha_alta VARCHAR, fecha_baja VARCHAR, estatus VARCHAR, dq_razon_corregida VARCHAR,
  es_omiso VARCHAR, ultimo_periodo_aportacion VARCHAR, fecha_carga VARCHAR
) WITH (format = 'CSV',
        external_location = 's3a://hive-bucket/inavit_raw/dim_patron/');

CREATE TABLE IF NOT EXISTS hive_data.inavit_raw.fact_aportacion (
  aportacion_id VARCHAR, nss VARCHAR, registro_patronal VARCHAR, periodo VARCHAR,
  sdi VARCHAR, dias_cotizados VARCHAR, monto_aportacion VARCHAR, fecha_pago VARCHAR,
  origen VARCHAR, fecha_registro VARCHAR, dq_dias_invalidos VARCHAR,
  dq_monto_cero VARCHAR, fecha_carga VARCHAR
) WITH (format = 'CSV',
        external_location = 's3a://hive-bucket/inavit_raw/fact_aportacion/');

CREATE TABLE IF NOT EXISTS hive_data.inavit_raw.fact_pago (
  pago_id VARCHAR, num_credito VARCHAR, fecha_pago VARCHAR, periodo VARCHAR,
  monto_pago VARCHAR, tipo_pago VARCHAR, canal VARCHAR, fecha_carga VARCHAR
) WITH (format = 'CSV',
        external_location = 's3a://hive-bucket/inavit_raw/fact_pago/');

-- NOTA: este conector no soporta skip_header_line_count; el encabezado entra como una fila
-- y se filtra en los CTAS (WHERE lower(<1a col>) <> '<nombre col>').
-- Prueba rapida de lectura (esperado: 33 / 15 / 15001, incluye la fila de encabezado)
-- SELECT COUNT(*) FROM hive_data.inavit_raw.dim_entidad;
-- SELECT COUNT(*) FROM hive_data.inavit_raw.dim_periodo;
-- SELECT COUNT(*) FROM hive_data.inavit_raw.dim_patron;

-- ---------- 3. DIMENSIONES A ICEBERG ----------
CREATE TABLE iceberg_data.inavit_dw.dim_entidad AS
SELECT clave, nombre, region,
       CAST(NULLIF(fecha_carga,'') AS TIMESTAMP) AS fecha_carga
FROM hive_data.inavit_raw.dim_entidad
WHERE lower(clave) <> 'clave';

CREATE TABLE iceberg_data.inavit_dw.dim_periodo AS
SELECT periodo,
       CAST(NULLIF(anio,'') AS INTEGER)     AS anio,
       CAST(NULLIF(bimestre,'') AS INTEGER) AS bimestre,
       CAST(NULLIF(fecha_inicio,'') AS DATE)      AS fecha_inicio,
       CAST(NULLIF(fecha_fin,'') AS DATE)         AS fecha_fin,
       CAST(NULLIF(fecha_limite_pago,'') AS DATE) AS fecha_limite_pago
FROM hive_data.inavit_raw.dim_periodo
WHERE lower(periodo) <> 'periodo';

CREATE TABLE iceberg_data.inavit_dw.dim_patron AS
SELECT registro_patronal, rfc, razon_social, sector, tamanio, entidad_clave,
       municipio, codigo_postal,
       CAST(NULLIF(fecha_alta,'') AS DATE) AS fecha_alta,
       CAST(NULLIF(fecha_baja,'') AS DATE) AS fecha_baja,
       estatus,
       CAST(NULLIF(dq_razon_corregida,'') AS INTEGER)  AS dq_razon_corregida,
       CAST(NULLIF(es_omiso,'') AS INTEGER)  AS es_omiso,
       NULLIF(ultimo_periodo_aportacion,'')            AS ultimo_periodo_aportacion,
       CAST(NULLIF(fecha_carga,'') AS TIMESTAMP)       AS fecha_carga
FROM hive_data.inavit_raw.dim_patron
WHERE lower(registro_patronal) <> 'registro_patronal';

-- ---------- 4. HECHOS A ICEBERG (solo HISTORIA, particionados por periodo) ----------
CREATE TABLE iceberg_data.inavit_dw.fact_aportacion
WITH (partitioning = ARRAY['periodo']) AS
SELECT CAST(aportacion_id AS BIGINT) AS aportacion_id,
       nss, registro_patronal, periodo,
       CAST(NULLIF(sdi,'') AS DECIMAL(10,2))              AS sdi,
       CAST(NULLIF(dias_cotizados,'') AS INTEGER)  AS dias_cotizados,
       CAST(NULLIF(monto_aportacion,'') AS DECIMAL(12,2)) AS monto_aportacion,
       CAST(NULLIF(fecha_pago,'') AS DATE)                AS fecha_pago,
       origen,
       CAST(NULLIF(fecha_registro,'') AS TIMESTAMP)       AS fecha_registro,
       CAST(NULLIF(dq_dias_invalidos,'') AS INTEGER)  AS dq_dias_invalidos,
       CAST(NULLIF(dq_monto_cero,'') AS INTEGER)  AS dq_monto_cero,
       CAST(NULLIF(fecha_carga,'') AS TIMESTAMP)          AS fecha_carga
FROM hive_data.inavit_raw.fact_aportacion
WHERE lower(aportacion_id) <> 'aportacion_id' AND periodo <= '202506';

CREATE TABLE iceberg_data.inavit_dw.fact_pago
WITH (partitioning = ARRAY['periodo']) AS
SELECT CAST(pago_id AS BIGINT)      AS pago_id,
       CAST(num_credito AS BIGINT)  AS num_credito,
       CAST(NULLIF(fecha_pago,'') AS DATE)        AS fecha_pago,
       periodo,
       CAST(NULLIF(monto_pago,'') AS DECIMAL(12,2)) AS monto_pago,
       tipo_pago, canal,
       CAST(NULLIF(fecha_carga,'') AS TIMESTAMP)  AS fecha_carga
FROM hive_data.inavit_raw.fact_pago
WHERE lower(pago_id) <> 'pago_id' AND periodo <= '202512';

-- ---------- 5. VALIDACION (comparar con Netezza, mismo filtro) ----------
SELECT 'fact_aportacion' AS tabla, COUNT(*) AS filas, SUM(monto_aportacion) AS suma
FROM iceberg_data.inavit_dw.fact_aportacion
UNION ALL
SELECT 'fact_pago', COUNT(*), SUM(monto_pago)
FROM iceberg_data.inavit_dw.fact_pago;

SELECT periodo, COUNT(*) AS filas FROM iceberg_data.inavit_dw.fact_aportacion
GROUP BY periodo ORDER BY periodo;

-- ---------- 5b. EQUIVALENTE EN NETEZZA (ejecutar en DBeaver) ----------
-- SELECT 'fact_aportacion' T, COUNT(*) N, SUM(MONTO_APORTACION) S
--   FROM INAVIT_DW.FACT_APORTACION WHERE PERIODO <= '202506'
-- UNION ALL
-- SELECT 'fact_pago', COUNT(*), SUM(MONTO_PAGO)
--   FROM INAVIT_DW.FACT_PAGO WHERE PERIODO <= '202512';
