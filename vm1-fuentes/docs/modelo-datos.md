# Modelo de datos INAVIT

Todo es sintético. NSS y CURP traen dígito verificador válido; los RFC tienen estructura plausible (la homoclave es aleatoria).

## Db2 · `INAVIT_APO` (aportaciones)

| Tabla | Llave | Filas (perfil demo) | Descripción |
|---|---|---|---|
| `PATRON` | `REGISTRO_PATRONAL` | ~15 mil | Razón social, RFC, sector, tamaño, entidad, estatus (A activo, S suspendido, B baja) |
| `TRABAJADOR` | `NSS` | ~251 mil | Datos personales, CURP, RFC, patrón actual, salario diario integrado, estatus (A/B) |
| `SUBCUENTA_VIVIENDA` | `NSS` | ~251 mil | Saldo en pesos, bimestres cotizados, última aportación |
| `APORTACION` | `APORTACION_ID` | ~2.6 M | Aportación bimestral (5% del SDI × días cotizados). `PERIODO` = `AAAABB` (BB = bimestre 01..06). `ORIGEN`: N normal, E extemporánea, D demo en vivo |

Ventana: 12 bimestres que terminan en el último cuya fecha límite de pago (día 17 del mes siguiente) ya pasó.
Los IDs de aportación van de 1 a ~2.6 M; la secuencia `SEQ_APORTACION` (para la demo en vivo) arranca en 100,000,000.

## SAP HANA · `INAVIT_FIN` (financiero)

| Tabla | Llave | Filas (perfil demo) | Descripción |
|---|---|---|---|
| `CAT_ENTIDAD` | `CLAVE` | 32 | Entidades federativas con región |
| `CAT_PRODUCTO_CREDITO` | `PRODUCTO_ID` | 5 | Productos (nombres inventados: Hogar Tradicional, Mejora Tu Hogar, Total, Unidos, Construye) |
| `CREDITO` | `NUM_CREDITO` | ~105 mil | Crédito con NSS/CURP/RFC "como se capturaron", saldo, estatus y días de mora |
| `PAGO` | `PAGO_ID` | ~2.2 M | Pagos mensuales de los últimos 24 meses |
| `COBRANZA` | `GESTION_ID` | ~25 mil | Gestiones de cobranza de créditos morosos o reestructurados |

## Llaves compartidas (para los joins de DataStage)
`NSS`, `CURP`, `RFC` y `REGISTRO_PATRONAL` son los mismos en Db2 y en HANA. Ojo: en HANA algunos vienen sucios y hay que normalizarlos (`TRIM`, `UPPER`) antes del join.

## Calidad de datos sembrada (aprox.)

| Dónde | Problema | Frecuencia |
|---|---|---|
| `TRABAJADOR` | Nombre/apellidos en mayúsculas, minúsculas, sin acentos o con espacio final | ~13% |
| `TRABAJADOR` | CURP nula / truncada a 17 caracteres | ~2% / ~0.4% |
| `TRABAJADOR` | RFC nulo | ~6% |
| `TRABAJADOR` | Fecha de nacimiento centinela (1900-01-01) o futura | ~0.5% / ~0.2% |
| `TRABAJADOR` | Duplicados: misma CURP con distinto NSS (sin aportaciones, `ESTATUS='B'`) | ~0.5% |
| `PATRON` | Razón social en minúsculas / doble espacio / espacio final | ~3% / ~2% / ~1% |
| `APORTACION` | `DIAS_COTIZADOS` > 62 / `MONTO_APORTACION` = 0 | ~0.04% cada uno |
| `CREDITO` | NSS que **no existe** en Db2 (huérfano) | ~0.4% |
| `CREDITO` | NSS con espacio inicial | ~0.3% |
| `CREDITO` | CURP nula, en minúsculas, en blanco o con un carácter alterado | ~3% / 4% / 1.5% / 0.5% |
| `CREDITO` | RFC nulo / en minúsculas | ~8% / 3% |
| `CREDITO` | `NOMBRE_ACREDITADO` en un solo campo con formatos distintos ("APELLIDOS NOMBRE", con acentos, "APELLIDOS, NOMBRE", doble espacio) | ~20% fuera del formato dominante |
| `CREDITO` | `ESTATUS_CREDITO` con variantes de captura (`Vigente`, `vigente `, `VIG`…) | ~4% de los vigentes |
| `CREDITO` | `MUNICIPIO` en mayúsculas | ~5% |

## Historia de negocio incluida
- **~7% de los patrones dejan de aportar** (omisos). Algunos siguen "activos" en el padrón (omisos ocultos). Sus trabajadores, o encuentran otro patrón tras un hueco de 1-3 bimestres, o quedan sin aportar.
- **Mora vs. patrón omiso:** acreditados que dejaron de aportar ≈ 39% de mora; los reubicados ≈ 14%; el resto ≈ 6.5%.
- **Mora por entidad** con variación suave (entre ~5% y ~11%). Los factores son inventados.
- **Precalificados:** trabajadores activos, sin crédito, con saldo y antigüedad altos (el manifiesto trae un conteo con una regla de ejemplo; Netezza definirá la suya).
- Los acreditados con crédito tienen la subcuenta casi en cero (su saldo se aplicó al enganche).
- **Reestructurados:** créditos con un periodo de mora ya regularizado y un convenio firmado en cobranza.

El resumen numérico de cada generación queda en `${DATA_DIR}/manifest.json` (KPIs en la clave `kpis_demo`).
