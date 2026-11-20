#!/usr/bin/env bash
# Verifica que la VM1 pueda correr HANA Express + Db2 + generador de datos.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

FALLAS=0
pasa()  { ok "$*"; }
falla() { printf '%s  ✘ %s%s\n' "$C_R" "$*" "$C_0" >&2; FALLAS=$((FALLAS + 1)); }

log "Preflight VM1"

# --- Docker -------------------------------------------------------------------
command -v docker >/dev/null || { falla "docker no está instalado"; exit 1; }
if docker info >/dev/null 2>&1; then
  pasa "Docker responde ($(docker --version | sed 's/Docker version //'))"
else
  falla "Docker no responde (¿systemctl start docker? ¿ejecutas como root o con sudo?)"; exit 1
fi

# --- Recursos --------------------------------------------------------------------
cpus="$(nproc)"
mem_gb="$(free -g | awk '/^Mem:/{print $2}')"
(( cpus >= 6 ))   && pasa "CPU: ${cpus} vCPU" || falla "CPU: ${cpus} vCPU (se recomiendan >= 8)"
if (( mem_gb >= 30 )); then pasa "RAM: ${mem_gb} GB"
elif (( mem_gb >= 24 )); then warn "RAM: ${mem_gb} GB (justo; recomendado >= 32 GB)"
else falla "RAM: ${mem_gb} GB (HANA + Db2 necesitan >= 24 GB)"; fi

# --- Disco ----------------------------------------------------------------------------
mkdir -p "$BASE_DIR"
base_gb="$(df -BG --output=avail "$BASE_DIR" | tail -1 | tr -dc '0-9')"
(( base_gb >= 150 )) && pasa "Disco en ${BASE_DIR}: ${base_gb} GB libres" \
  || falla "Disco en ${BASE_DIR}: ${base_gb} GB libres (HANA pide >= 100 GB y los datos + Db2 unos 30 GB más)"

droot="$(docker info -f '{{.DockerRootDir}}')"
dav_gb="$(df -BG --output=avail "$droot" | tail -1 | tr -dc '0-9')"
if (( dav_gb >= 25 )); then
  pasa "Docker root (${droot}): ${dav_gb} GB libres"
else
  falla "Docker root (${droot}) tiene solo ${dav_gb} GB libres; las imágenes de HANA y Db2 pesan ~15 GB."
  printf '      Solución:  sudo bash scripts/01b-move-docker-root.sh   (mueve Docker a %s)\n' "$DOCKER_DATA_ROOT" >&2
fi

# --- Contraseñas ----------------------------------------------------------------------
check_pw() {
  local name="$1" v="${!1}" prohibido=0
  case "$v" in
    *'`'*|*'$'*|*'\'*|*'"'*|*"'"*|*' '*) prohibido=1 ;;
  esac
  if [[ ${#v} -ge 8 && "$v" =~ [A-Z] && "$v" =~ [a-z] && "$v" =~ [0-9] ]] && (( ! prohibido )); then
    pasa "$name cumple la política"
  else
    falla "$name no cumple (>= 8, mayúscula+minúscula+número, sin \` \$ \\ comillas ni espacios)"
  fi
}
check_pw HANA_MASTER_PASSWORD; check_pw HANA_APP_PASSWORD; check_pw DB2_PASSWORD

# --- Puertos libres (si los contenedores no son los nuestros) -------------------------
for spec in "${HANA_SQL_PORT}:${HANA_CONTAINER}" "${DB2_PORT}:${DB2_CONTAINER}"; do
  port="${spec%%:*}"; owner="${spec##*:}"
  if container_running "$owner"; then
    pasa "Puerto ${port}: ocupado por ${owner} (esperado)"
  elif ss -ltn 2>/dev/null | awk -v p=":${port}\$" '$4 ~ p {f=1} END{exit !f}'; then
    falla "Puerto ${port} ya está en uso por otro proceso"
  else
    pasa "Puerto ${port} libre"
  fi
done

# --- Salida a registros de imágenes -----------------------------------------------------
for url in https://registry-1.docker.io/v2/ https://icr.io/v2/; do
  code="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$url" || true)"
  [[ "$code" =~ ^(200|401)$ ]] && pasa "Acceso a ${url}" || falla "Sin acceso a ${url} (HTTP ${code:-000})"
done

# --- Aviso de login para HANA ----------------------------------------------------------------
if ! docker image inspect "$HANA_IMAGE" >/dev/null 2>&1; then
  warn "La imagen ${HANA_IMAGE} no está descargada. Si el pull falla, ejecuta antes:  docker login"
fi

# --- SELinux ------------------------------------------------------------------------------------
if command -v getenforce >/dev/null 2>&1; then
  log "SELinux: $(getenforce) (los volúmenes nuevos usan :z)"
fi

if (( FALLAS > 0 )); then die "Preflight con ${FALLAS} falla(s). Corrígelas y vuelve a correr."; fi
ok "Preflight OK"
