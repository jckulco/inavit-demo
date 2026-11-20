# 10 · Cifras de referencia

Todas las cifras corresponden a los datos generados con `SEED=20261102` y `AS_OF=2026-11-02`, **sin** las 10
filas de la demo en vivo. Si una cifra no cuadra, revisa primero esos dos parámetros y las filas `ORIGEN = 'D'`.

## Fuentes (VM1)

| Sistema | Tabla | Filas |
|---|---|---|
| SAP HANA `INAVIT_FIN` | `CAT_ENTIDAD` / `CAT_PRODUCTO_CREDITO` | 32 / 5 |
| | `CREDITO` | 105,315 |
| | `PAGO` | 2,216,653 |
| | `COBRANZA` | 25,472 |
| Db2 `INAVIT_APO` | `PATRON` | 15,000 |
| | `TRABAJADOR` / `SUBCUENTA_VIVIENDA` | 251,272 / 251,272 |
| | `APORTACION` | 2,639,227 |

Staging (VM3) replica los mismos conteos: `INAVIT_STG` igual a Db2 y `hana_raw` igual a HANA.

## Netezza `INAVIT_DW`

| Tabla | Filas |
|---|---|
| `CREDITO_INTEGRADO` | 104,871 |
| `DQ_CREDITO_HUERFANO` | 444 |
| `DIM_ENTIDAD` / `DIM_PERIODO` / `DIM_PRODUCTO` | 32 / 14 / 5 |
| `DIM_PATRON` | 15,000 |
| `DIM_TRABAJADOR` / `FACT_SUBCUENTA` | 251,272 / 251,272 |
| `FACT_APORTACION` | 2,639,227 (suma `MONTO_APORTACION` 4,118,517,348.68) |
| `FACT_PAGO` | 2,216,653 (suma `MONTO_PAGO` 8,960,812,221.15) |
| `FACT_COBRANZA` | 25,472 |

Cuadre de cartera: 105,315 créditos en HANA = 104,871 integrados + 444 rechazados.

## Cognos

| Pestaña | KPIs |
|---|---|
| Cartera y morosidad | 104,871 créditos · MX$37,417,573,857 de saldo · MX$1,801,355,673 en patrones omisos · 8.2% de morosidad · mora con patrón omiso 38.7% contra 6.7% al corriente |
| Patrones omisos | 1,083 omisos · 455 omisos ocultos · 11,595 trabajadores afectados · MX$1,801,355,673 de saldo en riesgo |
| Precalificados | 25,583 · saldo promedio MX$225,527 · saldo acumulado MX$5,769,664,485 · 123 bimestres cotizados promedio |

Mora por producto: Mejora Tu Hogar 10.9%, Construye 8.9%, Hogar Tradicional 7.6%, Unidos 6.4%, Total 6.2%.

## watsonx.data

| Objeto | Filas | Suma |
|---|---|---|
| `iceberg_data.inavit_dw.fact_aportacion` (≤ 202506) | 1,713,809 | 2,642,127,743.50 |
| `iceberg_data.inavit_dw.fact_pago` (≤ 202512) | 1,219,692 | 4,625,913,931.47 |
| `v_fact_aportacion`, fuente netezza | 925,418 | 1,476,389,605.18 |
| `v_fact_pago`, fuente netezza | 996,961 | 4,334,898,289.68 |

Aportaciones por bimestre en Iceberg: 202405 202,179 · 202406 206,599 · 202501 208,811 · 202502 211,626 ·
202503 215,903 · 202504 219,116 · 202505 223,191 · 202506 226,384.
En Netezza, después del corte: 202601 230,153 · 202602 233,370 · 202603 232,935 · 202604 228,960.

## Con la demo en vivo

`FACT_APORTACION` 2,639,237 · fuente netezza de `v_fact_aportacion` 925,428 · 10 filas `ORIGEN = 'D'` en Db2,
SQL Server y Netezza.
