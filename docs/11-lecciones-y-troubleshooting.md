# 11 · Lecciones aprendidas y troubleshooting

Problemas reales que aparecieron al construir el proyecto, con la solución que funcionó.
Los de HANA y Db2 en Docker están en [`vm1-fuentes/docs/troubleshooting.md`](../vm1-fuentes/docs/troubleshooting.md).

## Datos y fuentes

| Síntoma | Causa | Solución |
|---|---|---|
| Las cifras no coinciden con las de referencia | `AS_OF` vacío: la ventana de periodos se calculó con otra fecha | `AS_OF=2026-11-02` en `.env` y regenerar (`04-generate-data.sh --force` y recargar) |
| `MUNICIPIO` distinto entre Db2 (`Jiutepec`) y Netezza (`JIUTEPEC`) | DataStage pasa el municipio a mayúsculas | Es esperado; Db2 guarda los municipios en formato título |

## Replicación (IIDR)

| Síntoma | Causa | Solución |
|---|---|---|
| Un cambio en Db2 no llega a SQL Server | La suscripción estaba detenida | Iniciarla: los cambios pendientes se aplican al arrancar. Revísala antes de cada demo |
| Las filas borradas siguen en Netezza | DataStage no propaga borrados | Borrar también en Netezza (`demo-live/`) |

## Staging y DataStage

| Síntoma | Causa | Solución |
|---|---|---|
| Cloud Pak for Data as a Service no llega a SQL Server | El puerto 1433 solo es accesible por túnel SSH | Túnel TCP de ngrok como servicio de Windows, restringido a los rangos de IP de IBM Cloud ([`03-staging-vm3.md`](03-staging-vm3.md)) |
| Riesgo de credenciales | Conexión de DataStage con `sa` | Login de solo lectura (`staging/sqlserver/02_login_lectura.sql`) |

## Netezza

| Síntoma | Causa | Solución |
|---|---|---|
| Un `COUNT(*)` tarda más de 10 minutos y DBeaver muestra "Cancel operation timed out" | Falla de la instancia SaaS | Forzar cierre de DBeaver, revisar la instancia en la consola de IBM Cloud (Netezza SaaS en Azure), reabrir y probar `SELECT 1` |
| *Disconnect* en DBeaver no desconecta | La conexión está bloqueada esperando al servidor | Cerrar DBeaver a la fuerza; al cortar la red, Netezza cierra la sesión |
| Falta el DDL para reconstruir | No hay script original | Reconstruirlo del catálogo: `_V_RELATION_COLUMN`, `_V_TABLE_DIST_MAP`, `_V_VIEW` (así se hizo `netezza/`) |

## Cognos

| Síntoma | Causa | Solución |
|---|---|---|
| `XQE-MSR-0023` con `V_PRECALIFICADOS` | Cognos guardó en caché metadatos viejos (12 de 16 columnas) | Tabla con *Native SQL* sobre `V_PRECALIFICADOS_DASH` |
| "Estimated number of cells exceeds 100000" en el Top 10 | Demasiadas columnas en la tabla | Cálculo `Patron Detalle` que concatena razón social, entidad y sector |
| El export no incluye el tablero | Estaba en *My content* | Moverlo a *Team content* |
| Al programar, aparece la especificación de import | Se abrió el schedule equivocado | Cancelar y programar el export `INAVIT_export` |
| La hora programada no coincide | El servidor está en UTC | Programar en hora UTC (02:00) |
| `scp` del respaldo da "Permission denied" | Permisos de la carpeta de respaldos | `chmod 755` de la carpeta y su padre antes del `chown` (ya está en `backup_inavit.sh`) |
| La conexión no funciona tras importar | Las contraseñas de conexiones no se exportan | Recrear la conexión `INAVIT_DW` a mano |

## watsonx.data

| Síntoma | Causa | Solución |
|---|---|---|
| Los puertos 9443/8443/9000/9001 no están en el host | Developer Edition corre en Kubernetes (KIND), no en Docker/Podman | `kubectl port-forward` hacia los servicios del namespace `wxd` (`start_forwards.sh`) |
| El puerto 8381 no abre la consola de Presto | 8381 es el Hive Metastore (thrift), no Presto | Presto es `ibm-lh-presto-svc:8443` |
| `~/wxd-remote-access/start_forwards.sh: No such file` | Como root, `~` es `/root`; el repo está en `/opt/repos/wxd-remote-access` | Usar la ruta completa |
| Los port-forwards se pierden | Son procesos de `kubectl` en la sesión | Volver a correr `start_forwards.sh` tras reiniciar (o unidades de `systemd`) |
| `brew install minio/stable/mc` y la descarga directa fallan con 410 | MinIO dejó de distribuir `mc` en `dl.min.io` | Consola web de MinIO o `rclone` |
| `Schema creation requires an explicit location` | El catálogo no asigna ubicación por defecto | `WITH (location = 's3a://...')` |
| `does not support table property 'skip_header_line_count'` | Conector Hive de esta versión | Filtrar el encabezado en el `CTAS` |
| `Type not supported for Iceberg: smallint` | Iceberg no tiene `SMALLINT` | `INTEGER` |
| `SHOW TABLES` del catálogo de Netezza tarda más de un minuto | Metadatos por JDBC a través de internet | Normal la primera vez; calentar antes de la demo |
