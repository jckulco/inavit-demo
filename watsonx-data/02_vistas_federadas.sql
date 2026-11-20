-- =============================================================================
-- INAVIT · watsonx.data (Presto, motor presto-01) · vistas federadas
-- Historia en Iceberg + periodos posteriores al corte leídos de Netezza.
-- Requisito: Netezza registrado como Data source con el catálogo netezza_inavit,
-- asociado a presto-01 (ver docs/07-watsonx-data.md).
-- Cortes: aportaciones periodo <= '202506' (bimestral) · pagos periodo <= '202512' (mensual)
-- =============================================================================

-- Prueba del catálogo de Netezza
SHOW SCHEMAS FROM netezza_inavit;                 -- demo, inavit_dw
SHOW TABLES FROM netezza_inavit.inavit_dw;        -- la primera vez puede tardar más de un minuto

SELECT periodo, COUNT(*) AS filas
FROM netezza_inavit.inavit_dw.fact_aportacion
WHERE periodo > '202506'
GROUP BY periodo ORDER BY periodo;                -- 202601..202604 (y 202606 si hay filas de la demo en vivo)

-- Aportaciones
CREATE OR REPLACE VIEW iceberg_data.inavit_dw.v_fact_aportacion AS
SELECT aportacion_id, nss, registro_patronal, periodo, sdi, dias_cotizados,
       monto_aportacion, fecha_pago, origen, fecha_registro, dq_dias_invalidos,
       dq_monto_cero, fecha_carga, 'lakehouse' AS fuente
FROM iceberg_data.inavit_dw.fact_aportacion
UNION ALL
SELECT CAST(aportacion_id AS BIGINT), nss, registro_patronal, periodo,
       CAST(sdi AS DECIMAL(10,2)), CAST(dias_cotizados AS INTEGER),
       CAST(monto_aportacion AS DECIMAL(12,2)), CAST(fecha_pago AS DATE), origen,
       CAST(fecha_registro AS TIMESTAMP), CAST(dq_dias_invalidos AS INTEGER),
       CAST(dq_monto_cero AS INTEGER), CAST(fecha_carga AS TIMESTAMP), 'netezza'
FROM netezza_inavit.inavit_dw.fact_aportacion
WHERE periodo > '202506';

-- Pagos
CREATE OR REPLACE VIEW iceberg_data.inavit_dw.v_fact_pago AS
SELECT pago_id, num_credito, fecha_pago, periodo, monto_pago, tipo_pago, canal,
       fecha_carga, 'lakehouse' AS fuente
FROM iceberg_data.inavit_dw.fact_pago
UNION ALL
SELECT CAST(pago_id AS BIGINT), CAST(num_credito AS BIGINT), CAST(fecha_pago AS DATE),
       periodo, CAST(monto_pago AS DECIMAL(12,2)), tipo_pago, canal,
       CAST(fecha_carga AS TIMESTAMP), 'netezza'
FROM netezza_inavit.inavit_dw.fact_pago
WHERE periodo > '202512';

-- Si este motor no permite vistas en iceberg_data, crea las mismas dos vistas en
-- hive_data.inavit_raw (mismo SQL, otro nombre de esquema).
