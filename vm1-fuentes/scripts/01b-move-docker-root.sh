#!/usr/bin/env bash
# Mueve el directorio de datos de Docker (/var/lib/docker) a un disco grande.
# Necesario en la VM1: /var tiene ~10 GB y las imágenes de HANA + Db2 pesan ~15 GB.
# ⚠ Detiene Docker unos minutos (se paran los contenedores en ejecución).
#   Uso: sudo bash scripts/01b-move-docker-root.sh [--yes]
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

YES=0; [[ "${1:-}" == "--yes" ]] && YES=1
ACTUAL="$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || echo /var/lib/docker)"
DEST="$DOCKER_DATA_ROOT"

[[ "$ACTUAL" == "$DEST" ]] && { ok "Docker ya usa ${DEST}"; exit 0; }

log "Docker root actual: ${ACTUAL}  ->  nuevo: ${DEST}"
running="$(docker ps -q 2>/dev/null | wc -l)"
(( running > 0 )) && warn "Hay ${running} contenedor(es) en ejecución; se detendrán."
if (( ! YES )); then
  read -r -p "¿Continuar? (s/N) " r
  [[ "$r" =~ ^[Ss]$ ]] || die "Cancelado."
fi

systemctl stop docker docker.socket 2>/dev/null || systemctl stop docker
mkdir -p "$DEST"
if command -v rsync >/dev/null; then
  rsync -aHAX --numeric-ids "${ACTUAL}/" "${DEST}/"
else
  warn "rsync no está instalado; usando cp -a"
  cp -a "${ACTUAL}/." "${DEST}/"
fi

# daemon.json: agrega "data-root" sin pisar otras opciones
mkdir -p /etc/docker
if [[ -s /etc/docker/daemon.json ]]; then
  cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%s)"
  python3 - "$DEST" <<'PY'
import json, sys
p = "/etc/docker/daemon.json"
d = json.load(open(p))
d["data-root"] = sys.argv[1]
json.dump(d, open(p, "w"), indent=2)
PY
else
  printf '{\n  "data-root": "%s"\n}\n' "$DEST" > /etc/docker/daemon.json
fi

# SELinux: el nuevo directorio debe heredar el contexto de /var/lib/docker
if command -v getenforce >/dev/null && [[ "$(getenforce)" != "Disabled" ]]; then
  if command -v semanage >/dev/null; then
    semanage fcontext -a -e /var/lib/docker "$DEST" 2>/dev/null || true
    restorecon -R "$DEST" 2>/dev/null || true
  else
    warn "SELinux activo y 'semanage' no disponible (dnf install policycoreutils-python-utils); si Docker falla al arrancar, restablece contextos con: restorecon -R ${DEST}"
  fi
fi

systemctl start docker
nuevo="$(docker info -f '{{.DockerRootDir}}')"
[[ "$nuevo" == "$DEST" ]] || die "Docker arrancó con ${nuevo}, no con ${DEST}. Revisa /etc/docker/daemon.json"
ok "Docker usa ahora ${DEST}"
log "Cuando verifiques que todo funciona puedes liberar espacio con:  rm -rf ${ACTUAL}"
