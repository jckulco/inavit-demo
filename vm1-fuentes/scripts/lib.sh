#!/usr/bin/env bash
# =============================================================================
# Funciones comunes. Uso:  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; load_env
# =============================================================================
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$LIB_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ -t 1 ]]; then
  C_B=$'\033[1;34m'; C_G=$'\033[1;32m'; C_Y=$'\033[1;33m'; C_R=$'\033[1;31m'; C_0=$'\033[0m'
else
  C_B=""; C_G=""; C_Y=""; C_R=""; C_0=""
fi
log()  { printf '%s[%s]%s %s\n' "$C_B" "$(date +%H:%M:%S)" "$C_0" "$*"; }
ok()   { printf '%s  ✔%s %s\n' "$C_G" "$C_0" "$*"; }
warn() { printf '%s  ⚠%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
die()  { printf '%s  ✘ %s%s\n' "$C_R" "$*" "$C_0" >&2; exit 1; }

load_env() {
  [[ -f "$ENV_FILE" ]] || die "No existe $ENV_FILE. Corre primero: bash scripts/00-init-env.sh"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  local v
  for v in HANA_MASTER_PASSWORD HANA_APP_PASSWORD DB2_PASSWORD; do
    [[ -n "${!v:-}" ]] || die "Falta $v en $ENV_FILE"
  done
}

# (sin tuberías: con pipefail, 'grep -q' puede cortar el pipe y devolver 141)
container_exists()  { [[ -n "$(docker ps -a -q -f "name=^/${1}\$")" ]]; }
container_running() { [[ -n "$(docker ps -q -f "name=^/${1}\$" -f status=running)" ]]; }

# ---- SAP HANA ---------------------------------------------------------------
# hdb_run <BASE> [args de hdbsql...]   BASE = HXE (tenant) | SYSTEMDB
# Los argumentos viajan como parámetros posicionales: sin problemas de comillas.
hdb_run() {
  local db="$1"; shift
  docker exec -i -u hxeadm -e "HP=${HANA_MASTER_PASSWORD}" "$HANA_CONTAINER" \
    bash -lc 'db="$1"; inst="$2"; shift 2; hdbsql -i "$inst" -d "$db" -u SYSTEM -p "$HP" "$@"' \
    _ "$db" "$HANA_INSTANCE" "$@" </dev/null
}
# hdb_scalar <BASE> "<SQL>"  -> primer valor, sin comillas ni espacios
hdb_scalar() { hdb_run "$1" -a -x -j "$2" 2>/dev/null | tr -d '"\r ' | head -n1; }
# hdb_file <BASE> <archivo.sql>  -> copia y ejecuta el archivo dentro del contenedor
hdb_file() {
  local db="$1" f="$2" base; base="$(basename "$f")"
  docker cp "$f" "${HANA_CONTAINER}:/tmp/${base}"
  docker exec -u root "$HANA_CONTAINER" chmod 644 "/tmp/${base}"
  hdb_run "$db" -I "/tmp/${base}"
}

# ---- Db2 -----------------------------------------------------------------------
# db2_sh "<comandos de shell como db2inst1>"  (una sola sesión: conserva la conexión)
db2_sh() { docker exec -i "$DB2_CONTAINER" su - db2inst1 -c "$1" </dev/null; }
# db2_scalar "<SQL sin comillas dobles>"  -> primer valor
db2_scalar() {
  db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null && db2 -x \"$1\"" 2>/dev/null | tr -d '\r ' | head -n1
}
# db2_file <archivo.sql>  -> ejecuta con 'db2 -tvf' conectado a la base
db2_file() {
  local f="$1" base; base="$(basename "$f")"
  docker cp "$f" "${DB2_CONTAINER}:/tmp/${base}"
  docker exec -u root "$DB2_CONTAINER" chmod 644 "/tmp/${base}"
  db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null && db2 -tvf /tmp/${base}"
}

# ---- Utilidades -----------------------------------------------------------------
# wait_until <timeout_seg> <intervalo_seg> <descripción> <comando...>
wait_until() {
  local timeout="$1" step="$2" desc="$3"; shift 3
  local t=0
  while ! "$@" >/dev/null 2>&1; do
    if (( t >= timeout )); then return 1; fi
    if (( t % 60 == 0 )); then log "esperando: ${desc} (${t}s)"; fi
    sleep "$step"; t=$((t + step))
  done
}

# Carga el manifiesto de datos generados (ROWS_* y MF_*)
load_manifest() {
  [[ -f "${DATA_DIR}/manifest.env" ]] || die "No hay datos generados. Corre scripts/04-generate-data.sh"
  set -a
  # shellcheck disable=SC1091
  source "${DATA_DIR}/manifest.env"
  set +a
}
