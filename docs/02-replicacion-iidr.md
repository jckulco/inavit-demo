# 02 · Replicación Db2 → SQL Server con IBM Data Replication (IIDR)

IIDR lee el log de transacciones de Db2 y aplica los cambios en SQL Server en segundos.
No usa triggers ni consultas periódicas sobre la fuente.

## Piezas

| Pieza | Dónde | Nota |
|---|---|---|
| Motor CDC origen (Db2 Replication Engine) | Host de VM1 (RHEL 9.8) | Con el cliente Db2 del host catalogado contra el contenedor `db2server` |
| Motor CDC destino (SQL Server Replication Engine) | VM3 (Windows Server 2025) | Apunta a la base `INAVIT_STG` |
| Access Server | VM2 (RHEL 9.8) | Coordina los motores; Management Console se conecta a él |
| Management Console | VM3 (Windows Server 2025) | La interfaz que se muestra en la demo |

## Configuración

1. **Cliente Db2 en el host de VM1**, de la misma versión que la imagen del contenedor (12.1.5):

   ```bash
   db2 catalog tcpip node INAVNODE remote localhost server 50000
   db2 catalog database INAVITDB as INAVITDB at node INAVNODE
   db2 terminate
   db2 connect to INAVITDB user db2inst1
   ```

2. **Instancia del motor CDC para Db2** contra `INAVITDB`. El motor pide un directorio de carga masiva con
   lectura y escritura para Db2 y para CDC; con Db2 en un contenedor, ese directorio debe ser visible para
   ambos (un volumen compartido).
3. **Instancia del motor CDC para SQL Server** en VM3, contra `INAVIT_STG`.
4. **Tablas destino** en `INAVIT_STG.INAVIT_APO`: créalas con [`staging/sqlserver/01_inavit_stg.sql`](../staging/sqlserver/01_inavit_stg.sql)
   o deja que IIDR las cree al mapear.
5. **Suscripción** en Management Console, origen el motor Db2 y destino el motor SQL Server.
   Mapea en modo estándar (espejo) las tablas `PATRON`, `TRABAJADOR`, `SUBCUENTA_VIVIENDA` y `APORTACION`.
6. **Refresh inicial** y luego **Start mirroring** (continuo). El estado debe quedar en *Mirroring*.

## Guardar la configuración en el repositorio

La suscripción del proyecto original no está exportada aquí. Para que el repositorio la conserve:

- En Management Console, exporta la suscripción (clic derecho sobre la suscripción, *Export*), o
- usa `dmexportconfiguration` en cada motor,

y guarda el XML en `iidr/` (por ejemplo `iidr/subscription_INAVIT.xml`). Anota en [`iidr/README.md`](../iidr/README.md)
el nombre de la suscripción y de los datastores.

## Validación

```sql
-- En Db2 y en SQL Server, mismos conteos:
SELECT COUNT(*) FROM INAVIT_APO.PATRON;             -- 15000
SELECT COUNT(*) FROM INAVIT_APO.TRABAJADOR;         -- 251272
SELECT COUNT(*) FROM INAVIT_APO.SUBCUENTA_VIVIENDA; -- 251272
SELECT COUNT(*) FROM INAVIT_APO.APORTACION;         -- 2639227
```

Prueba de latencia: inserta una fila en Db2 (bloque del paso 4 de
[`demo-live/INAVIT_demo_live_reset.sql`](../demo-live/INAVIT_demo_live_reset.sql)) y búscala en SQL Server.

## Lo que hay que saber

- **IIDR tiene que estar en Mirroring antes de cualquier cambio en Db2.** Si está detenido, los cambios no se
  pierden: se aplican al reiniciar la suscripción. En el proyecto original un borrado hecho con IIDR detenido
  llegó a SQL Server solo cuando se reinició.
- La replicación borra en SQL Server lo que se borra en Db2 (espejo). DataStage no propaga borrados a Netezza;
  por eso el reset de la demo en vivo también borra en Netezza.
