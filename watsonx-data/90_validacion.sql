-- =============================================================================
-- INAVIT · watsonx.data · validación (validado el 19 de noviembre de 2026)
-- =============================================================================

-- 1. Historia en Iceberg (debe coincidir con Netezza aplicando el mismo corte)
SELECT 'fact_aportacion' AS tabla, COUNT(*) AS filas, SUM(monto_aportacion) AS suma
FROM iceberg_data.inavit_dw.fact_aportacion                -- 1,713,809 · 2,642,127,743.50
UNION ALL
SELECT 'fact_pago', COUNT(*), SUM(monto_pago)
FROM iceberg_data.inavit_dw.fact_pago;                      -- 1,219,692 · 4,625,913,931.47

-- 8 bimestres de 202405 a 202506 (202179, 206599, 208811, 211626, 215903, 219116, 223191, 226384)
SELECT periodo, COUNT(*) AS filas FROM iceberg_data.inavit_dw.fact_aportacion
GROUP BY periodo ORDER BY periodo;

-- 2. Vistas federadas: la suma de las dos fuentes = Netezza completo
SELECT fuente, COUNT(*) AS filas, SUM(monto_aportacion) AS suma
FROM iceberg_data.inavit_dw.v_fact_aportacion GROUP BY fuente;
-- lakehouse 1,713,809 · 2,642,127,743.50
-- netezza     925,418 · 1,476,389,605.18      total 2,639,227 · 4,118,517,348.68
-- (con las 10 filas de la demo en vivo, netezza = 925,428)

SELECT fuente, COUNT(*) AS filas, SUM(monto_pago) AS suma
FROM iceberg_data.inavit_dw.v_fact_pago GROUP BY fuente;
-- lakehouse 1,219,692 · 4,625,913,931.47
-- netezza     996,961 · 4,334,898,289.68      total 2,216,653 · 8,960,812,221.15

-- 3. Equivalente en Netezza (DBeaver), para comparar
-- SELECT COUNT(*), SUM(MONTO_APORTACION) FROM INAVIT_DW.FACT_APORTACION WHERE PERIODO <= '202506';
-- SELECT COUNT(*), SUM(MONTO_PAGO)       FROM INAVIT_DW.FACT_PAGO       WHERE PERIODO <= '202512';
-- SELECT COUNT(*), SUM(MONTO_APORTACION) FROM INAVIT_DW.FACT_APORTACION;   -- 2,639,227 · 4,118,517,348.68
-- SELECT COUNT(*), SUM(MONTO_PAGO)       FROM INAVIT_DW.FACT_PAGO;         -- 2,216,653 · 8,960,812,221.15
