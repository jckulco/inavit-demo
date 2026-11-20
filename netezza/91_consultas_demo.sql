-- =============================================================================
-- INAVIT_DW · consultas que se muestran en la demo (actos 4 y 5 del guion)
-- =============================================================================

-- ---- Acto 4: calidad de datos ----------------------------------------------
-- Estatus normalizado a un solo catálogo
SELECT ESTATUS_CREDITO, COUNT(*) AS N
FROM INAVIT_DW.CREDITO_INTEGRADO GROUP BY ESTATUS_CREDITO ORDER BY N DESC;

-- Registros corregidos por cada regla
SELECT SUM(DQ_NSS_CORREGIDO)      AS NSS,
       SUM(DQ_CURP_CORREGIDA)     AS CURP,
       SUM(DQ_ESTATUS_CORREGIDO)  AS ESTATUS,
       SUM(DQ_NOMBRE_CORREGIDO)   AS NOMBRE,
       SUM(DQ_FECHA_NAC_INVALIDA) AS FECHA_NAC
FROM INAVIT_DW.CREDITO_INTEGRADO;

-- Cuadre con HANA: 104,871 + 444 = 105,315
SELECT (SELECT COUNT(*) FROM INAVIT_DW.CREDITO_INTEGRADO)   AS INTEGRADOS,
       (SELECT COUNT(*) FROM INAVIT_DW.DQ_CREDITO_HUERFANO) AS RECHAZADOS;

SELECT MOTIVO, COUNT(*) AS N FROM INAVIT_DW.DQ_CREDITO_HUERFANO GROUP BY MOTIVO;

-- Llegada de las 10 aportaciones en vivo
SELECT COUNT(*) FROM INAVIT_DW.FACT_APORTACION;    -- 2,639,237 con la demo; 2,639,227 sin ella
SELECT APORTACION_ID, NSS, PERIODO, MONTO_APORTACION, FECHA_CARGA
FROM INAVIT_DW.FACT_APORTACION WHERE ORIGEN = 'D' ORDER BY APORTACION_ID;

-- ---- Acto 5: modelo y reglas de negocio --------------------------------------
-- Mora con patrón omiso contra el resto (Cognos: 38.7% contra 6.7%)
SELECT COALESCE(PATRON_OMISO, 0) AS PATRON_OMISO,
       COUNT(*) AS CREDITOS,
       SUM(ES_MOROSO) AS MOROSOS,
       ROUND(100.0 * SUM(ES_MOROSO) / COUNT(*), 1) AS PCT_MORA
FROM INAVIT_DW.V_FACT_CREDITO
GROUP BY COALESCE(PATRON_OMISO, 0);

-- Patrones omisos y omisos ocultos: 1,083 y 455
SELECT COUNT(*) AS OMISOS, SUM(OMISO_OCULTO) AS OCULTOS, SUM(SALDO_EN_RIESGO) AS SALDO_EN_RIESGO
FROM INAVIT_DW.V_PATRON_OMISO;

-- Recaudación por bimestre sobre 2.6 millones de aportaciones
SELECT PERIODO, COUNT(*) AS APORTACIONES, SUM(MONTO_APORTACION) AS MONTO
FROM INAVIT_DW.V_FACT_APORTACION GROUP BY PERIODO ORDER BY PERIODO;

-- Precalificados: 25,583
SELECT COUNT(*) FROM INAVIT_DW.V_PRECALIFICADOS;
