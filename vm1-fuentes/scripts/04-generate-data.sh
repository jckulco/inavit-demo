#!/usr/bin/env bash
# Genera los CSV sintéticos (en un contenedor Python; no requiere nada en el host).
# Uso: 04-generate-data.sh [--force]
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1

mkdir -p "${DATA_DIR}/db2" "${DATA_DIR}/hana"

# ¿Ya hay datos con los mismos parámetros?
if (( ! FORCE )) && [[ -f "${DATA_DIR}/manifest.env" ]]; then
  # shellcheck disable=SC1091
  ( source "${DATA_DIR}/manifest.env"
    [[ "$MF_SEED" == "$SEED" && "$MF_WORKERS" == "$SCALE_WORKERS" && "$MF_PATRONES" == "$SCALE_PATRONES" \
       && "$MF_BIMESTRES" == "$BIMESTRES" && "$MF_PAGO_MESES" == "$PAGO_MESES" \
       && ( -z "${AS_OF:-}" || "$MF_AS_OF" == "$AS_OF" ) ]] ) \
  && { ok "Datos ya generados con los mismos parámetros (usa --force para regenerar)"; exit 0; }
fi

log "Construyendo imagen inavit-datagen"
docker build --network host -q -t inavit-datagen "$ROOT_DIR/datagen" >/dev/null || die "Falló docker build (¿hay salida a pypi.org para instalar hdbcli?)"

rm -f "${DATA_DIR}"/db2/*.csv "${DATA_DIR}"/hana/*.csv "${DATA_DIR}"/manifest.*
log "Generando datos (≈1-2 min con el perfil por defecto)"
docker run --rm -v "${DATA_DIR}:/data:z" \
  -e SCALE_WORKERS="$SCALE_WORKERS" -e SCALE_PATRONES="$SCALE_PATRONES" \
  -e BIMESTRES="$BIMESTRES" -e PAGO_MESES="$PAGO_MESES" -e SEED="$SEED" \
  inavit-datagen python generate.py --out /data ${AS_OF:+--as-of "$AS_OF"}

log "Validando coherencia de los CSV"
docker run --rm -v "${DATA_DIR}:/data:ro,z" inavit-datagen python check_data.py --data /data \
  || die "check_data.py reportó fallas; revisa la salida de arriba."

# Db2 (db2inst1 dentro del contenedor) debe poder leer los archivos
chmod -R a+rX "$DATA_DIR"
ok "Datos listos en ${DATA_DIR} (manifest.json tiene los KPIs de la historia de la demo)"
