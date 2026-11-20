# 08 · Demo en vivo: las 10 aportaciones

El momento en vivo inserta 10 aportaciones en Db2 y las sigue por toda la cadena:

```
Db2 ──IIDR (segundos)──► SQL Server ──DataStage (flujo 2)──► Netezza ──► vista federada de watsonx.data
```

Todas las filas llevan `ORIGEN = 'D'`, `PERIODO = '202606'` y `APORTACION_ID` de 100000000 a 100000009, así se
reconocen y se borran sin tocar los datos base. Script: [`demo-live/INAVIT_demo_live_reset.sql`](../demo-live/INAVIT_demo_live_reset.sql).

## Antes de la demo: línea base

| Dónde | Consulta | Esperado |
|---|---|---|
| Db2 | `SELECT COUNT(*) FROM INAVIT_APO.APORTACION WHERE ORIGEN = 'D';` | 0 |
| SQL Server | `SELECT COUNT(*) FROM INAVIT_APO.APORTACION WHERE ORIGEN = 'D';` | 0 |
| Netezza | `SELECT COUNT(*) FROM INAVIT_DW.FACT_APORTACION;` | 2,639,227 |
| IIDR | Estado de la suscripción | *Mirroring* |

## Durante la demo

1. **Db2:** ejecuta el paso 4 del script (los 10 `INSERT`). DBeaver en Auto-commit.
2. **SQL Server:** en segundos, `SELECT ... WHERE ORIGEN = 'D'` devuelve 10 filas.
3. **DataStage:** corre el flujo de carga a Netezza.
4. **Netezza:** `FACT_APORTACION` sube a 2,639,237 y las 10 filas aparecen con su `FECHA_CARGA`.
5. **watsonx.data:** en `v_fact_aportacion` la fuente `netezza` pasa de 925,418 a 925,428
   (el periodo 202606 es posterior al corte, así que se lee de Netezza).

Alternativa más visual: `bash vm1-fuentes/scripts/demo-live-insert.sh -n 10 -d 2` en VM1 inserta una aportación
cada 2 segundos con la secuencia `SEQ_APORTACION`. **Ojo:** ese script también suma cada aportación a
`SUBCUENTA_VIVIENDA` (saldo y bimestres), y el reset no revierte ese cambio. Para grabaciones repetibles usa los
`INSERT` fijos.

## Después de la demo: reset

DataStage no propaga borrados a Netezza, así que se limpia en las dos puntas:

1. **Db2:** paso 1 del script (`DELETE` de las 10 filas).
2. **SQL Server:** espera un minuto y verifica que IIDR replicó el borrado (`COUNT(*)` = 0). Si sigue en 10,
   IIDR está detenido: inícialo (aplica el borrado pendiente) o corre el `DELETE` comentado del paso 2.
3. **Netezza:** paso 3 del script. `FACT_APORTACION` vuelve a 2,639,227.
4. Repite la tabla de línea base.

## Por qué los `INSERT` son fijos

Los valores salen de una corrida real de `demo-live-insert.sh` (3 de noviembre de 2026). Fijarlos garantiza que
cada ensayo y cada grabación muestren las mismas filas y que el reset las encuentre por su `APORTACION_ID`.
Si cambias los `INSERT`, cambia también los `DELETE` de los pasos 1 a 3.
