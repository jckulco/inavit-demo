# 03 · VM3: staging (Windows Server 2025 · SQL Server 2019 + PostgreSQL)

VM3 (Windows Server 2025) es la zona de aterrizaje. Recibe los datos crudos de las dos fuentes; nada de aquí llega a Cognos.
También aloja el motor de Data Replication para SQL Server y la Management Console de IIDR.

| Base | Motor | Llena | Contenido |
|---|---|---|---|
| `INAVIT_STG`, esquema `INAVIT_APO` | SQL Server 2019 | IIDR (CDC desde Db2) | Patrones, trabajadores, subcuentas y aportaciones |
| `inavit_stg`, esquema `hana_raw` | PostgreSQL | DataStage (lote desde HANA) | Catálogos, créditos, pagos y cobranza |

## SQL Server

1. Crea la base y las tablas: [`staging/sqlserver/01_inavit_stg.sql`](../staging/sqlserver/01_inavit_stg.sql)
   (o deja que IIDR las cree al mapear la suscripción).
2. Crea un login de solo lectura para DataStage: [`staging/sqlserver/02_login_lectura.sql`](../staging/sqlserver/02_login_lectura.sql).
3. Instala el motor CDC destino para SQL Server (ver [`02-replicacion-iidr.md`](02-replicacion-iidr.md)).
4. Valida: [`staging/sqlserver/90_validacion.sql`](../staging/sqlserver/90_validacion.sql).

Versión y edición de la instancia:

```powershell
sqlcmd -S localhost -E -Q "SELECT SERVERPROPERTY('ProductVersion'), SERVERPROPERTY('ProductLevel'), SERVERPROPERTY('Edition')"
```

### Acceso desde el plano de control de DataStage (ngrok)

DataStage as a Service Anywhere tiene el plano de control en IBM Cloud y el motor remoto en VM2 (Docker).
El motor remoto llega a VM3 por la red de las VMs, pero el plano de control en la nube no llega a
`localhost:1433`. En el proyecto original la conexión de Cloud Pak for Data as a Service hacia SQL Server se
resolvió publicando SQL Server con un túnel **ngrok** TCP, instalado como servicio de Windows y restringido a
los rangos de IP de IBM Cloud:

```powershell
# C:\ngrok\ngrok.yml (pon tu authtoken; no lo subas al repositorio)
# version: 3
# agent: { authtoken: <TU_AUTHTOKEN> }
# endpoints:
#   - name: sqlserver
#     url: tcp://<tu-endpoint>.tcp.ngrok.io:<puerto>
#     upstream: { url: 1433 }
#     traffic_policy:
#       on_tcp_connect:
#         - actions:
#             - type: restrict-ips
#               config: { enforce: true, allow: [<rangos de IP de IBM Cloud de tu región>] }
cd C:\ngrok
.\ngrok config check --config C:\ngrok\ngrok.yml
.\ngrok service install --config C:\ngrok\ngrok.yml
.\ngrok service start
Get-Service ngrok        # debe estar Running
```

Con el túnel expuesto, usa el login de solo lectura en DataStage (nunca `sa`). Para DBeaver no hace falta ngrok:
sigue usando el túnel SSH a `localhost:1433`.

## PostgreSQL

1. Crea la base `inavit_stg` y el esquema: [`staging/postgresql/01_hana_raw.sql`](../staging/postgresql/01_hana_raw.sql).
2. El flujo de DataStage de HANA a PostgreSQL llena `hana_raw` (ver [`04-datastage.md`](04-datastage.md)).
3. Valida: [`staging/postgresql/90_validacion.sql`](../staging/postgresql/90_validacion.sql).

> Los DDL de staging de este repositorio son equivalentes a los de las fuentes. Si en el proyecto original
> DataStage o IIDR crearon las tablas con otros nombres o tipos, ajusta los archivos a lo que tengas
> (`SELECT * FROM INFORMATION_SCHEMA.COLUMNS` en ambas bases) y vuelve a subirlos.
