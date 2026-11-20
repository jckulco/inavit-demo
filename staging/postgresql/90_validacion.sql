-- hana_raw: conteos esperados (iguales a SAP HANA INAVIT_FIN)
SELECT 'cat_entidad' AS tabla, COUNT(*) FROM hana_raw.cat_entidad            -- 32
UNION ALL SELECT 'cat_producto_credito', COUNT(*) FROM hana_raw.cat_producto_credito -- 5
UNION ALL SELECT 'credito', COUNT(*) FROM hana_raw.credito                   -- 105315
UNION ALL SELECT 'pago', COUNT(*) FROM hana_raw.pago                         -- 2216653
UNION ALL SELECT 'cobranza', COUNT(*) FROM hana_raw.cobranza;                -- 25472
