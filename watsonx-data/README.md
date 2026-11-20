# watsonx.data · historia en Iceberg y vistas federadas

Guía completa: [`docs/07-watsonx-data.md`](../docs/07-watsonx-data.md).

| Archivo | Dónde se ejecuta | Qué hace |
|---|---|---|
| `start_forwards.sh` | VM4, como root | Port-forwards de la consola (6443), MinIO (9001, 9000) y Presto (8443) |
| `01_carga_historica.sql` | Query workspace, `presto-01`, una sentencia a la vez | Esquemas, tablas externas sobre los CSV y `CTAS` a Iceberg con los cortes |
| `02_vistas_federadas.sql` | Query workspace | Vistas `v_fact_aportacion` y `v_fact_pago` (Iceberg + Netezza) |
| `90_validacion.sql` | Query workspace (y DBeaver para Netezza) | Conteos y sumas contra Netezza |
