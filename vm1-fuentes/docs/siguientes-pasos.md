# Siguientes pasos después de la VM1

Lo que **ya deja listo** esta VM para el resto de la demo:
- Db2 con `LOGARCHMETH1` activo, base UTF-8, tablas con llave primaria y un respaldo tomado.
- HANA con un usuario de solo lectura (`INAVIT_DS`) para DataStage.

## 1. Motor de replicación de Db2 (IIDR/CDC) en el host de la VM1
Enfoque acordado: instalar el **cliente de Db2 en el host** y apuntarlo al contenedor, de modo que el instalador del motor de CDC reconozca la instancia.

```bash
# Con el cliente Db2 instalado en el host (misma versión que la imagen del contenedor):
db2 catalog tcpip node INAVNODE remote localhost server 50000
db2 catalog database INAVITDB as INAVITDB at node INAVNODE
db2 terminate
db2 connect to INAVITDB user db2inst1       # prueba de conexión
```
Notas de la documentación de CDC for Db2 LUW:
- El motor se configura contra una instancia de Db2; para leer logs de una base **remota** hay que instalar un cliente compatible y catalogar la base (lo de arriba).
- Pide un directorio de carga masiva con permisos de lectura y escritura para Db2 **y** para CDC. Con la base dentro del contenedor, ese directorio debe ser visible para ambos (p. ej. un volumen compartido).
- Los logs archivados están en `/opt/inavit/db2/database/archive_logs` (host) = `/database/archive_logs` (contenedor).
- Confirma con tu instalador de Data Replication AI Edition (v12) qué opciones de despliegue incluye para el motor de Db2.

## 2. Puertos que habrá que exponer por túnel desde la VM1
| Servicio | Puerto | Quién lo usa |
|---|---|---|
| SAP HANA (tenant HXE) | 39041 | DataStage Remote Engine (VM2) |
| Db2 | 50000 | Cliente/Access Server (consulta y catalogación) |
| Motor CDC de Db2 | el que configures (por defecto 10901) | Motor de SQL Server y Access Server (VM2/VM3) |

## 3. DataStage → HANA
- Driver JDBC de SAP: `ngdbc.jar` (en tu repo `sap-hana-datastage-lab`, `docs/08-jdbc-driver-setup.md`, está el detalle del campo *Jar uris* y el bug del punto y coma).
- Usuario: `INAVIT_DS` · esquema `INAVIT_FIN` · URL `jdbc:sap://<host>:39041/?databaseName=HXE` (o el puerto SQL del tenant).
- Flujo de ejemplo: `INAVIT_FIN.CREDITO` → PostgreSQL (staging).

## 4. Momento "tiempo real"
Con la suscripción de CDC activa (Db2 → SQL Server) sobre `INAVIT_APO.APORTACION` y `SUBCUENTA_VIVIENDA`:
```bash
bash scripts/demo-live-insert.sh -n 10 -d 2
```
Cada inserción trae `ORIGEN='D'` y actualiza también la subcuenta, así se ven INSERT y UPDATE replicados.
