#!/usr/bin/env bash
# SAP HANA Express en Docker (basado en tu repo sap-hana-datastage-lab).
# Uso: 02-hana-up.sh [start|wait|all]
#   start -> crea/arranca el contenedor y regresa (HANA tarda 5-15 min en inicializar)
#   wait  -> espera "Startup finished!", limita memoria y crea el usuario de aplicación
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
MODE="${1:-all}"

hana_start() {
  mkdir -p "$HANA_DATA_DIR"
  chmod 777 "$HANA_DATA_DIR"          # el proceso interno corre como hxeadm (UID 12000)
  docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1 || { log "Creando red ${DOCKER_NETWORK}"; docker network create "$DOCKER_NETWORK" >/dev/null; }

  if container_running "$HANA_CONTAINER"; then ok "${HANA_CONTAINER} ya está en ejecución"; return 0; fi
  if container_exists "$HANA_CONTAINER"; then
    log "Arrancando contenedor existente ${HANA_CONTAINER}"; docker start "$HANA_CONTAINER" >/dev/null; return 0
  fi

  if ! docker image inspect "$HANA_IMAGE" >/dev/null 2>&1; then
    log "Descargando ${HANA_IMAGE} (varios GB)…"
    docker pull "$HANA_IMAGE" || die "No se pudo descargar la imagen. Ejecuta 'docker login' (Docker Hub) y reintenta."
  fi

  printf '{ "master_password" : "%s" }\n' "$HANA_MASTER_PASSWORD" > "${HANA_DATA_DIR}/password.json"
  chmod 600 "${HANA_DATA_DIR}/password.json"
  chown 12000:79 "${HANA_DATA_DIR}/password.json"      # HANA lo lee y lo elimina solo

  local avail_gb; avail_gb="$(df -BG --output=avail "$HANA_DATA_DIR" | tail -1 | tr -dc '0-9')"
  (( avail_gb >= 100 )) || warn "Solo ${avail_gb} GB libres en ${HANA_DATA_DIR}: HANA puede quedarse en 'Creating tenant database'."

  log "Creando contenedor ${HANA_CONTAINER}"
  docker run -h hxehost \
    --name "$HANA_CONTAINER" \
    --network "$DOCKER_NETWORK" \
    --network-alias hxehost \
    --restart unless-stopped \
    --stop-timeout 300 \
    -p 39013:39013 -p 39017:39017 -p 39041-39045:39041-39045 \
    -p 1128-1129:1128-1129 -p 59013-59014:59013-59014 \
    -v "${HANA_DATA_DIR}:/hana/mounts" \
    --ulimit nofile=1048576:1048576 \
    --sysctl net.ipv4.ip_local_port_range='40000 60999' \
    -d \
    "$HANA_IMAGE" \
    --passwords-url file:///hana/mounts/password.json \
    --agree-to-sap-license >/dev/null
  ok "Contenedor creado. HANA se está inicializando (primer arranque: 5-15 min)."
}

hana_started() {
  local l; l="$(docker logs "$HANA_CONTAINER" 2>&1 || true)"
  [[ "$l" == *"Startup finished!"* ]]
}

hana_wait() {
  container_running "$HANA_CONTAINER" || die "El contenedor ${HANA_CONTAINER} no está en ejecución. Revisa: docker logs ${HANA_CONTAINER}"
  log "Esperando 'Startup finished!' de HANA…"
  local t=0 max=3000
  until hana_started; do
    container_running "$HANA_CONTAINER" || die "HANA se detuvo. Últimas líneas:\n$(docker logs --tail 20 "$HANA_CONTAINER" 2>&1)"
    (( t < max )) || die "HANA no terminó de arrancar en $((max / 60)) min. Ver docs/troubleshooting.md §HANA (¿disco lleno en 'Creating tenant database'?)"
    if (( t % 60 == 0 )); then log "HANA sigue iniciando (${t}s) · $(docker logs --tail 1 "$HANA_CONTAINER" 2>&1 | cut -c1-110)"; fi
    sleep 15; t=$((t + 15))
  done
  ok "HANA reporta 'Startup finished!'"

  tenant_ok() { [[ "$(hdb_scalar "$HANA_TENANT" 'SELECT 1 FROM DUMMY')" == "1" ]]; }
  wait_until 300 10 "tenant ${HANA_TENANT} aceptando SQL" tenant_ok \
    || die "El tenant no responde. Si ves SQLSTATE 28000 revisa docs/troubleshooting.md (usuario SYSTEM bloqueado)."
  ok "Tenant ${HANA_TENANT} responde a SQL"

  # Límite de memoria del motor (deja RAM para Db2 y el motor de replicación)
  if hdb_run SYSTEMDB -x -j "ALTER SYSTEM ALTER CONFIGURATION ('global.ini','SYSTEM') SET ('memorymanager','global_allocation_limit') = '${HANA_MEM_LIMIT_MB}' WITH RECONFIGURE" >/dev/null 2>&1; then
    ok "global_allocation_limit = ${HANA_MEM_LIMIT_MB} MB"
  else
    warn "No se pudo fijar global_allocation_limit (continúa sin límite explícito)"
  fi

  # Usuario de aplicación para DataStage
  local existe; existe="$(hdb_scalar "$HANA_TENANT" "SELECT COUNT(*) FROM SYS.USERS WHERE USER_NAME='${HANA_APP_USER}'")"
  if [[ "$existe" == "0" ]]; then
    hdb_run "$HANA_TENANT" -x -j "CREATE USER ${HANA_APP_USER} PASSWORD \"${HANA_APP_PASSWORD}\" NO FORCE_FIRST_PASSWORD_CHANGE" >/dev/null \
      || die "No se pudo crear el usuario ${HANA_APP_USER}"
    hdb_run "$HANA_TENANT" -x -j "ALTER USER ${HANA_APP_USER} DISABLE PASSWORD LIFETIME" >/dev/null || true
    ok "Usuario ${HANA_APP_USER} creado"
  else
    ok "Usuario ${HANA_APP_USER} ya existe"
  fi
}

case "$MODE" in
  start) hana_start ;;
  wait)  hana_wait ;;
  all)   hana_start; hana_wait ;;
  *)     die "Uso: $0 [start|wait|all]" ;;
esac
