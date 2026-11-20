# INAVIT · VM1 · Fuentes de datos (SAP HANA Express + Db2)

Deja la **VM1** de la demo lista con dos fuentes de datos pobladas con datos sintéticos de México:

| Fuente | Rol en la demo | Esquema | Contenido |
|---|---|---|---|
| **SAP HANA Express** (Docker) | Módulo financiero: originación, cartera y cobranza. DataStage lo extrae a PostgreSQL | `INAVIT_FIN` | catálogos, ~105 mil créditos, ~2.2 M de pagos, ~25 mil gestiones de cobranza |
| **Db2 Community** (Docker) | Sistema de aportaciones patronales. Data Replication lo replica a SQL Server | `INAVIT_APO` | ~15 mil patrones, ~251 mil trabajadores y subcuentas, ~2.6 M de aportaciones |

INAVIT es una institución **ficticia**; todos los datos son **sintéticos** (nombres, NSS, CURP, RFC, registros patronales, salarios).

## Requisitos
- RHEL 9, Docker, 8 vCPU y ~32 GB de RAM, disco grande en `/opt` (HANA pide ≥ 100 GB libres).
- Salida a internet: Docker Hub, `icr.io` y PyPI (para el driver `hdbcli`).
- Si la descarga de la imagen de HANA falla, corre antes `docker login`.
- **Espacio de Docker:** si `/var` es pequeño (≈10 GB), el preflight te lo dirá y correrás una sola vez
  `sudo bash scripts/01b-move-docker-root.sh`, que mueve Docker a `/opt/docker`.

## Uso rápido

```bash
cd vm1-fuentes        # carpeta del repositorio inavit-demo, copiada a la VM1
sudo bash bootstrap.sh
```

El script es **idempotente**: si algo falla, corrige y vuelve a correrlo; salta lo que ya está hecho.
Tiempo esperado: 25-45 min (casi todo es el primer arranque de HANA; los datos se generan en paralelo).

Qué hace, en orden:

| Paso | Script | Qué hace |
|---|---|---|
| 0 | `00-init-env.sh`, `00-preflight.sh` | Crea `.env` con contraseñas generadas y valida recursos, disco, puertos y accesos |
| 1 | `01-setup-host.sh` | Sysctls de kernel para HANA (los de tu repo `sap-hana-datastage-lab`) |
| 2 | `02-hana-up.sh start`, `03-db2-up.sh start` | Arranca los dos contenedores |
| 3 | `04-generate-data.sh` | Genera y valida los CSV (≈1 min) mientras los contenedores se inicializan |
| 4-5 | `02-hana-up.sh wait`, `03-db2-up.sh wait` | Espera a HANA, fija su memoria, crea el usuario `INAVIT_DS`; crea la base `INAVITDB` (UTF-8) y el esquema en Db2 |
| 6 | `05-load-hana.sh`, `06-load-db2.sh` | Carga con `hdbcli` (HANA) y `LOAD` (Db2) y compara contra el manifiesto |
| 7 | `07-db2-archive-logging.sh` | Activa el log de archivo de Db2 (requisito de CDC) y toma el respaldo offline |
| 8 | `99-verify.sh` | Verificación final y parámetros de conexión |

## Credenciales y puertos
- Las contraseñas se generan en `.env` (permisos 600). Si las editas con símbolos, entrecomílla el valor.
- **HANA:** puerto `39041` (tenant `HXE`), usuario `INAVIT_DS` (solo lectura sobre `INAVIT_FIN`) y `SYSTEM`.
- **Db2:** puerto `50000`, base `INAVITDB`, usuario `db2inst1`.
- Ambos contenedores están en la red Docker `sap-demo-net` y tienen `--restart unless-stopped`.

## Utilidades
```bash
bash scripts/sql.sh hana "SELECT ESTATUS_CREDITO, COUNT(*) FROM INAVIT_FIN.CREDITO GROUP BY ESTATUS_CREDITO"
bash scripts/sql.sh db2  "SELECT COUNT(*) FROM INAVIT_APO.APORTACION"
bash scripts/demo-live-insert.sh -n 10 -d 2     # momento "tiempo real": 10 aportaciones, una cada 2 s
```

## Ajustar el volumen
En `.env`: `SCALE_WORKERS`, `SCALE_PATRONES`, `BIMESTRES`, `PAGO_MESES`. Luego:
```bash
bash scripts/04-generate-data.sh --force && bash scripts/05-load-hana.sh --force && bash scripts/06-load-db2.sh --force
```
(Las aportaciones se generan con `SEED` fija: los mismos parámetros dan siempre los mismos datos.)

## Estructura
```
bootstrap.sh            orquesta todo
.env.example            parámetros
scripts/                pasos numerados + utilidades (lib.sh, sql.sh, demo-live-insert.sh)
sql/db2, sql/hana       DDL
datagen/                generador, validador y cargador de HANA (se ejecutan en un contenedor Python)
docs/                   modelo de datos, troubleshooting y siguientes pasos
```

## Documentación
- [`docs/modelo-datos.md`](docs/modelo-datos.md): tablas, llaves compartidas y la "suciedad" sembrada para DataStage.
- [`docs/troubleshooting.md`](docs/troubleshooting.md): problemas conocidos de HANA, Db2 y la carga.
- [`docs/siguientes-pasos.md`](docs/siguientes-pasos.md): cliente Db2 en el host, motor de replicación, puertos para los túneles.

## Estado de pruebas
Probado en un entorno sin Docker: el generador a escala completa, el validador de coherencia, la correspondencia DDL ↔ generador (`python3 datagen/test_schema.py`), la sintaxis y `shellcheck` de todos los scripts, y el paso de argumentos y contraseñas con símbolos hacia `hdbsql`. **No se ejecutaron contra HANA ni Db2 reales**; la primera corrida en la VM1 es la prueba de integración. Los puntos con más probabilidad de requerir ajuste están en `docs/troubleshooting.md`.
