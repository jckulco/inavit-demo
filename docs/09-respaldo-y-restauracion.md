# 09 · Respaldo y restauración

El proyecto se puede reconstruir desde cero con este repositorio más tres piezas que no viven en git.

| Pieza | Qué contiene | Dónde vive | Cómo se genera |
|---|---|---|---|
| Este repositorio | Instalador de VM1, DDL, vistas, scripts, guías | GitHub | — |
| ZIP de Cognos | Carpeta INAVIT: tablero (3 pestañas) y módulo `INAVIT_DM`, 72 objetos, cifrado | VM5 `/mnt/second/backups/inavit/` y copia local | Export programado + `backup_inavit.sh` |
| Contraseña del ZIP | Necesaria para importar | Gestor de contraseñas | — |
| CSV de Netezza (11 tablas, ~540 MB) | Datos del almacén | Fuera de git (disco o *release asset* privado) | DBeaver *Export Data* |
| Export de DataStage | Los dos flujos y sus conexiones | `datastage/export/` (local) | Export ZIP del proyecto |
| Export de IIDR | Suscripción Db2 → SQL Server | `iidr/` | Export de Management Console |

## Restauración completa (ambiente nuevo)

1. VM1: `bash bootstrap.sh` con `AS_OF=2026-11-02` ([`01-vm1-fuentes.md`](01-vm1-fuentes.md)).
2. VM3: DDL de staging ([`03-staging-vm3.md`](03-staging-vm3.md)).
3. IIDR: suscripción, refresh y mirroring ([`02-replicacion-iidr.md`](02-replicacion-iidr.md)).
4. Netezza: `00_schema.sql` y `01_tables.sql`.
5. Datos de Netezza, **una** de dos rutas:
   - DataStage: importar flujos, correr flujo 1 y flujo 2 ([`04-datastage.md`](04-datastage.md)).
   - CSV: *Import Data* en DBeaver por tabla ([`05-netezza.md`](05-netezza.md)).
6. Netezza: `02_views.sql` y `90_validacion.sql`.
7. Cognos: conexión `INAVIT_DW`, copiar el ZIP e importar ([`06-cognos.md`](06-cognos.md)).
8. watsonx.data: CSV a MinIO, carga histórica y vistas federadas ([`07-watsonx-data.md`](07-watsonx-data.md)).
9. Validación final: [`10-cifras-de-referencia.md`](10-cifras-de-referencia.md).

## Restauración parcial

| Si se perdió… | Haz |
|---|---|
| Solo el tablero de Cognos | Paso 7 (el ZIP más reciente de VM5) |
| El esquema de Netezza | Pasos 4 a 6, luego revisa que Cognos sigue apuntando a `INAVIT_DW` |
| VM4 (watsonx.data) | Reinstala con `wxd-remote-access` y repite el paso 8 |
| Solo los port-forwards de VM4 | `bash watsonx-data/start_forwards.sh` |
| Filas de demo en vivo sobrantes | [`08-demo-en-vivo.md`](08-demo-en-vivo.md), sección reset |

## Qué ya se probó

- Import del ZIP de Cognos en una carpeta aparte: *Succeeded*, 0 objetos fallidos (18 nov 2026).
- DDL de tablas y vistas de Netezza en un esquema limpio (`INAVIT_TEST`): sin errores (18 nov 2026).
- Carga de los CSV a Netezza: correcta (18 nov 2026).
- Carga histórica y vistas federadas en watsonx.data: totales idénticos a Netezza (19 nov 2026).

Pendiente de probar: recrear la conexión `INAVIT_DW` de Cognos en un ambiente realmente nuevo.
