#!/usr/bin/env bash
# Db2 Community Edition en Docker, con la base INAVITDB lista para CDC (IIDR).
# Uso: 03-db2-up.sh [start|wait|all] [--reset-schema]
#   start -> crea/arranca el contenedor y regresa
#   wait  -> espera a Db2, crea INAVITDB (UTF-8), ajusta memoria/logs y crea el esquema
# El archivado de logs (requisito de CDC) se activa DESPUÉS de cargar los datos: scripts/07.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
MODE="${1:-all}"
RESET=0; [[ "${2:-}" == "--reset-schema" ]] && RESET=1

# acepta códigos de salida 0-2 del CLP (0 ok, 1 sin filas, 2 advertencia)
db2_try() { local rc=0; db2_sh "$1" || rc=$?; (( rc <= 2 )) || return "$rc"; }

db2_start() {
  mkdir -p "$DB2_DATA_DIR" "${DATA_DIR}/db2" "${DATA_DIR}/hana"
  chmod 777 "$DB2_DATA_DIR"
  chmod 755 "$DATA_DIR" "${DATA_DIR}/db2" "${DATA_DIR}/hana"
  docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1 || docker network create "$DOCKER_NETWORK" >/dev/null

  if container_running "$DB2_CONTAINER"; then ok "${DB2_CONTAINER} ya está en ejecución"; return 0; fi
  if container_exists "$DB2_CONTAINER"; then
    log "Arrancando contenedor existente ${DB2_CONTAINER}"; docker start "$DB2_CONTAINER" >/dev/null; return 0
  fi

  if ! docker image inspect "$DB2_IMAGE" >/dev/null 2>&1; then
    log "Descargando ${DB2_IMAGE}…"
    docker pull "$DB2_IMAGE" || die "No se pudo descargar ${DB2_IMAGE}"
  fi

  log "Creando contenedor ${DB2_CONTAINER}"
  docker run -d \
    --name "$DB2_CONTAINER" -h "$DB2_CONTAINER" \
    --network "$DOCKER_NETWORK" \
    --restart unless-stopped \
    --privileged=true \
    --shm-size 4g \
    -p "${DB2_PORT}:50000" \
    -e LICENSE=accept \
    -e DB2INSTANCE=db2inst1 \
    -e DB2INST1_PASSWORD="$DB2_PASSWORD" \
    -e PERSISTENT_HOME=true \
    -e HADR_ENABLED=false \
    -e TO_CREATE_SAMPLEDB=false \
    -e REPODB=false \
    -e UPDATEAVAIL=NO \
    -v "${DB2_DATA_DIR}:/database:z" \
    -v "${DATA_DIR}:/inavit_data:z" \
    "$DB2_IMAGE" >/dev/null
  ok "Contenedor creado. Db2 configura la instancia (varios minutos)."
}

db2_ready() {
  local l; l="$(docker logs "$DB2_CONTAINER" 2>&1 || true)"
  [[ "$l" == *"Setup has completed"* ]] && return 0
  local o; o="$(db2_sh 'db2pd - 2>&1 | head -n 3' 2>/dev/null || true)"
  [[ "$o" == *"-- Active --"* ]]
}

db2_wait() {
  container_running "$DB2_CONTAINER" || die "El contenedor ${DB2_CONTAINER} no está en ejecución. Revisa: docker logs ${DB2_CONTAINER}"
  log "Esperando a que Db2 termine su configuración inicial…"
  local t=0 max=1800
  until db2_ready; do
    container_running "$DB2_CONTAINER" || die "Db2 se detuvo. Últimas líneas:\n$(docker logs --tail 20 "$DB2_CONTAINER" 2>&1)"
    (( t < max )) || die "Db2 no quedó listo en $((max / 60)) min. Revisa: docker logs ${DB2_CONTAINER}"
    if (( t % 60 == 0 )); then log "Db2 sigue configurándose (${t}s) · $(docker logs --tail 1 "$DB2_CONTAINER" 2>&1 | cut -c1-110)"; fi
    sleep 10; t=$((t + 10))
  done
  sleep 10
  ok "Db2 listo"
  db2_try "db2start" >/dev/null 2>&1 || true   # no-op si ya está activa (SQL1026N)

  # --- base de datos UTF-8 (para acentos y Ñ) ---------------------------------------
  local hay; hay="$(db2_sh "db2 list db directory 2>/dev/null | grep -ci 'Database name *= *${DB2_DBNAME}\$' || true" | tr -d '\r ' | tail -n1)"
  if [[ "${hay:-0}" == "0" ]]; then
    log "Creando base ${DB2_DBNAME} (UTF-8, páginas de 32 KB)… puede tardar 1-3 min"
    db2_try "db2 \"CREATE DATABASE ${DB2_DBNAME} AUTOMATIC STORAGE YES ON /database/data DBPATH ON /database/data USING CODESET UTF-8 TERRITORY US COLLATE USING IDENTITY PAGESIZE 32 K\"" \
      || die "No se pudo crear ${DB2_DBNAME}"
    ok "Base ${DB2_DBNAME} creada"
  else
    ok "Base ${DB2_DBNAME} ya existe"
  fi

  # --- ajustes de memoria y de log transaccional ----------------------------------------
  local pages=$(( DB2_INSTANCE_MEMORY_GB * 262144 ))     # páginas de 4 KB
  db2_try "db2 update dbm cfg using INSTANCE_MEMORY ${pages}" >/dev/null || warn "No se pudo fijar INSTANCE_MEMORY"
  db2_try "db2 update db cfg for ${DB2_DBNAME} using LOGFILSIZ 8192 LOGPRIMARY 10 LOGSECOND 40" >/dev/null || warn "No se pudieron ajustar los logs"
  ok "INSTANCE_MEMORY=${DB2_INSTANCE_MEMORY_GB} GB · LOGFILSIZ=8192 LOGPRIMARY=10 LOGSECOND=40"

  # --- esquema ---------------------------------------------------------------------------------
  if (( RESET )); then
    log "Eliminando esquema INAVIT_APO (--reset-schema)"
    db2_file "$ROOT_DIR/sql/db2/00_drop.sql" >/dev/null 2>&1 || true
  fi
  local ntab; ntab="$(db2_scalar "SELECT COUNT(*) FROM SYSCAT.TABLES WHERE TABSCHEMA='INAVIT_APO' AND TYPE='T'")"
  if [[ "$ntab" == "4" ]]; then
    ok "Esquema INAVIT_APO ya creado (4 tablas)"
  else
    log "Creando esquema INAVIT_APO"
    db2_file "$ROOT_DIR/sql/db2/01_schema.sql" >/dev/null || true
    ntab="$(db2_scalar "SELECT COUNT(*) FROM SYSCAT.TABLES WHERE TABSCHEMA='INAVIT_APO' AND TYPE='T'")"
    [[ "$ntab" == "4" ]] || die "El esquema INAVIT_APO no quedó completo (${ntab:-0}/4 tablas). Corre: bash scripts/03-db2-up.sh wait --reset-schema"
    ok "Esquema INAVIT_APO creado (4 tablas, secuencia e índices)"
  fi
}

case "$MODE" in
  start) db2_start ;;
  wait)  db2_wait ;;
  all)   db2_start; db2_wait ;;
  *)     die "Uso: $0 [start|wait|all] [--reset-schema]" ;;
esac
