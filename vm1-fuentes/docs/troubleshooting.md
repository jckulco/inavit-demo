# Troubleshooting

## Espacio en disco / Docker
- **`no space left on device` al hacer `docker pull`:** `/var` es chico (≈10 GB) y Docker guarda ahí las imágenes.
  Corre `sudo bash scripts/01b-move-docker-root.sh` (mueve Docker a `DOCKER_DATA_ROOT`, por defecto `/opt/docker`).
  Si SELinux está activo y Docker no arranca tras el cambio: `restorecon -R /opt/docker`.

## SAP HANA Express
(Heredado de tu repo `sap-hana-datastage-lab`.)

- **Warnings `Operation not permitted: move_pages` / `mbind`:** el perfil seccomp de Docker bloquea syscalls NUMA. No impiden el arranque; solo afectan rendimiento en cargas intensivas.
- **Error de `sysctl kernel.shmmni`/memoria compartida en `docker run`:** esos parámetros van en el host (`scripts/01-setup-host.sh`), no en `docker run`.
- **Se queda en "Creating tenant database" más de 20-30 min:** casi siempre es disco lleno.
  `docker stats --no-stream hxe` (si el CPU está alto, trabaja), y `tail -100 /opt/inavit/saphana/trace/hxehost/nameserver_alert_hxehost.trc` buscando `Disk was full`.
  Solución: `docker rm -f hxe`, vacía `HANA_DATA_DIR` en una partición con espacio y vuelve a correr `scripts/02-hana-up.sh`.
- **`hdbsql: executable file not found` / `su: Authentication failure`:** usa siempre `docker exec -u hxeadm hxe bash -lc '…'` (login shell). Los scripts ya lo hacen.
- **`SYSTEM` bloqueado (SQLSTATE 28000 con la contraseña correcta):** el bloqueo persiste aunque reinicies. Desde `SYSTEMDB`:
  ```bash
  docker exec -it -u hxeadm hxe bash -lc 'hdbsql -i 90 -d SYSTEMDB -u SYSTEM -p "<pw>" "ALTER SYSTEM STOP DATABASE HXE"'
  docker exec -it -u hxeadm hxe bash -lc 'hdbsql -i 90 -d SYSTEMDB -u SYSTEM -p "<pw>" "ALTER DATABASE HXE SYSTEM USER PASSWORD \"NuevaPassword123\""'
  docker exec -it -u hxeadm hxe bash -lc 'hdbsql -i 90 -d SYSTEMDB -u SYSTEM -p "<pw>" "ALTER SYSTEM START DATABASE HXE"'
  ```
  HANA no reutiliza las últimas 5 contraseñas. Actualiza `HANA_MASTER_PASSWORD` en `.env` con la nueva.
- **Imagen:** el repositorio correcto es `saplabs/hanaexpress` (no `store/saplabs/hanaexpress`).
- **El `password.json` desaparece** tras el primer arranque: es normal, HANA lo lee y lo elimina.

## Db2 Community (Docker)
- **Necesita `--privileged`:** sin él el contenedor no arranca (el script ya lo usa).
- **Se reinicia el contenedor y falla con `DBI20187E` (fencedid):** es un problema documentado en la imagen `12.1.0.0`. Una respuesta de IBM Community (jun-2026) indica que está resuelto en `12.1.5.0` y `latest`, que es lo que usa `.env.example`. Si usas una versión anterior: `docker cp` de `/var/db2_setup/lib/setup_db2_instance.sh`, agrégale `chown root:db2iadm1 /database/config/db2inst1/sqllib/adm/fencedid`, y cópialo de vuelta.
- **El script se queda esperando "Db2 listo":** `docker logs -f db2server`. La primera configuración tarda varios minutos. El script acepta como señal el mensaje `Setup has completed` o que `db2pd -` reporte la instancia activa; si tu versión de la imagen usa otro texto, la segunda condición lo cubre.
- **`SQL1116N … BACKUP PENDING` al conectar:** se activó el log de archivo y falta el respaldo offline. Corre `bash scripts/07-db2-archive-logging.sh` (lo toma).
- **`LOAD` falla con `SQL3500W/SQL3501W/SQL3025N`:** revisa el archivo de mensajes: `docker exec db2server cat /tmp/load_<TABLA>.msg`. Verifica que `/opt/inavit/data/db2/*.csv` existan y sean legibles (`chmod -R a+rX /opt/inavit/data`).
- **Acentos mal cargados:** la base debe ser UTF-8. `99-verify.sh` lo comprueba. Si ya existía una base creada de otra forma, bórrala o cambia `DB2_DBNAME`.
- **Memoria:** `INSTANCE_MEMORY` se fija en `DB2_INSTANCE_MEMORY_GB` (6 GB por defecto). Súbela si Db2 se queda corto.

## Generación y carga de HANA (hdbcli)
- **`docker build` falla (`Temporary failure in name resolution`):** los contenedores en la red bridge por defecto no resuelven DNS en algunas VMs; el script ya usa `--network host` para el build. Si lo necesitas en otros contenedores, agrega `"dns": ["8.8.8.8"]` a `/etc/docker/daemon.json` y reinicia Docker.
- **`No se pudo conectar a HANA`:** el cargador prueba el puerto SQL del tenant (`HANA_SQL_PORT`, 39041) y luego `39017` + `databaseName`, con y sin TLS. Confirma el puerto con
  `bash scripts/sql.sh hana "SELECT SQL_PORT FROM SYS_DATABASES.M_SERVICES WHERE SERVICE_NAME='indexserver'"`
  (si no resuelve, ejecútalo con `-d SYSTEMDB`).
- **Error de privilegios al leer con `INAVIT_DS`:** el `GRANT` está en `sql/hana/01_schema.sql`; vuelve a correr `bash scripts/05-load-hana.sh --force`.
- **El DROP inicial muestra `invalid schema name`:** es esperado la primera vez.

## Datos
- `python3 datagen/test_schema.py` confirma que el DDL y el generador tienen las mismas columnas en el mismo orden (si cambias uno, cambia el otro).
- `docker run --rm -v /opt/inavit/data:/data:ro inavit-datagen python check_data.py --data /data` vuelve a validar los CSV.
