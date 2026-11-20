# 01 · VM1: fuentes de datos (SAP HANA + Db2)

El paquete [`vm1-fuentes/`](../vm1-fuentes/) deja la VM1 lista con un solo comando: levanta los dos contenedores,
genera los datos sintéticos y los carga. Es idempotente: si algo falla, corriges y lo vuelves a correr.

```bash
scp -r vm1-fuentes itzuser@<vm1>:/tmp/
ssh itzuser@<vm1>
sudo -i
cd /tmp/vm1-fuentes && bash bootstrap.sh
```

Detalle de cada paso, credenciales y ajustes de volumen: [`vm1-fuentes/README.md`](../vm1-fuentes/README.md).
Problemas conocidos de HANA, Db2 y la carga: [`vm1-fuentes/docs/troubleshooting.md`](../vm1-fuentes/docs/troubleshooting.md).

## Qué queda al terminar

| Fuente | Contenedor | Puerto | Esquema | Filas |
|---|---|---|---|---|
| SAP HANA Express | `hxe` | 39041 (tenant HXE) | `INAVIT_FIN` | 32 entidades, 5 productos, 105,315 créditos, 2,216,653 pagos, 25,472 gestiones |
| Db2 Community 12.1.5 | `db2server` | 50000 | `INAVITDB.INAVIT_APO` | 15,000 patrones, 251,272 trabajadores y subcuentas, 2,639,227 aportaciones |

Estas son las cifras de la generación original: `SEED=20261102`, `AS_OF=2026-11-02`, 12 bimestres de `202405`
a `202604` y 24 meses de pagos. El `.env.example` de este repositorio ya trae esos dos valores, así que una
instalación nueva produce los mismos datos.

> Si dejas `AS_OF` vacío, la ventana de periodos se calcula con la fecha del servidor y todas las cifras de
> referencia de este repositorio (Netezza, Cognos, watsonx.data) cambian, así como los cortes de historia.

## Requisitos para IIDR que el paquete ya cumple

- Base `INAVITDB` en UTF-8 y todas las tablas con llave primaria.
- `LOGARCHMETH1` activo (log de archivo) y respaldo offline tomado (`scripts/07-db2-archive-logging.sh`).
- Logs archivados en `/opt/inavit/db2/database/archive_logs` (host) = `/database/archive_logs` (contenedor).
- Secuencia `INAVIT_APO.SEQ_APORTACION` desde 100,000,000 para las filas de la demo en vivo.

El motor de CDC de Db2 se instala en el host de VM1 con un cliente Db2 catalogado contra el contenedor; ver
[`02-replicacion-iidr.md`](02-replicacion-iidr.md) y [`vm1-fuentes/docs/siguientes-pasos.md`](../vm1-fuentes/docs/siguientes-pasos.md).

## Verificación rápida

```bash
bash scripts/99-verify.sh
bash scripts/sql.sh db2  "SELECT COUNT(*) FROM INAVIT_APO.APORTACION"          # 2639227
bash scripts/sql.sh hana "SELECT COUNT(*) FROM INAVIT_FIN.CREDITO"             # 105315
```

## Nota sobre el estado de pruebas del paquete

El `README.md` del paquete dice que sus scripts no se habían ejecutado contra HANA ni Db2 reales. Eso se
escribió antes de la primera instalación. Con ese paquete se construyó la VM1 del proyecto, y los conteos de la
tabla de arriba son los que se validaron después en Db2, SQL Server y Netezza.
