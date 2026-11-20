#!/usr/bin/env bash
# Activa el log de archivo de Db2 (LOGARCHMETH1) y toma el respaldo offline obligatorio.
# Es requisito para que el motor de InfoSphere Data Replication (CDC) lea los cambios.
# Se corre DESPUÉS de cargar los datos: así no se archivan GBs de logs de la carga inicial.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
container_running "$DB2_CONTAINER" || die "Db2 no está en ejecución"

ARCH=/database/archive_logs
BKP=/database/backup

actual="$(db2_sh "db2 get db cfg for ${DB2_DBNAME} | grep -i 'LOGARCHMETH1'" 2>/dev/null | tr -d '\r' || true)"
if [[ "$actual" == *"DISK:"* ]]; then
  ok "Log de archivo ya habilitado: $(echo "$actual" | sed 's/  */ /g')"
  exit 0
fi

docker exec -u root "$DB2_CONTAINER" bash -c "mkdir -p ${ARCH} ${BKP} && chown db2inst1: ${ARCH} ${BKP}"

log "Habilitando LOGARCHMETH1=DISK:${ARCH}"
db2_sh "db2 update db cfg for ${DB2_DBNAME} using LOGARCHMETH1 DISK:${ARCH}" >/dev/null

log "Reiniciando la instancia (aplica INSTANCE_MEMORY y libera conexiones)"
db2_sh "db2 force application all; db2 terminate; db2stop force; db2start" >/dev/null 2>&1 || true

log "Respaldo offline (obligatorio tras activar el log de archivo)"
out="$(db2_sh "db2 backup database ${DB2_DBNAME} to ${BKP}" 2>&1)" || true
printf '%s\n' "$out" | tail -n 3 | sed 's/^/    /'
[[ "$out" == *"Backup successful"* ]] || die "El respaldo falló; la base queda en BACKUP PENDING hasta que se tome."

actual="$(db2_sh "db2 get db cfg for ${DB2_DBNAME} | grep -i 'LOGARCHMETH1'" 2>/dev/null | tr -d '\r' || true)"
[[ "$actual" == *"DISK:"* ]] || die "LOGARCHMETH1 no quedó activo"
db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null && db2 -x \"SELECT COUNT(*) FROM INAVIT_APO.APORTACION\"" >/dev/null \
  || die "No se puede conectar a ${DB2_DBNAME} tras el respaldo"
ok "Log de archivo activo y base disponible: $(echo "$actual" | sed 's/  */ /g')"
