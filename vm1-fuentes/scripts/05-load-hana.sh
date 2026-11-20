#!/usr/bin/env bash
# Crea el esquema INAVIT_FIN en SAP HANA y carga los CSV (hdbcli, ~2.4 M de filas).
# Uso: 05-load-hana.sh [--force]
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
load_manifest
FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1

container_running "$HANA_CONTAINER" || die "HANA no está en ejecución"
TABLAS=(CAT_ENTIDAD CAT_PRODUCTO_CREDITO CREDITO PAGO COBRANZA)

cuenta_ok() {
  local t n esperado var
  for t in "${TABLAS[@]}"; do
    n="$(hdb_scalar "$HANA_TENANT" "SELECT COUNT(*) FROM INAVIT_FIN.${t}" || true)"
    var="ROWS_HANA_${t}"; esperado="${!var}"
    [[ "$n" == "$esperado" ]] || return 1
  done
}

if (( ! FORCE )) && cuenta_ok 2>/dev/null; then
  ok "HANA ya tiene los datos esperados (usa --force para recargar)"
  exit 0
fi

log "Creando esquema INAVIT_FIN (el error del DROP inicial en la primera corrida es normal)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
sed "s/__APP_USER__/${HANA_APP_USER}/g" "$ROOT_DIR/sql/hana/01_schema.sql" > "${TMP}/inavit_fin_schema.sql"
hdb_file "$HANA_TENANT" "${TMP}/inavit_fin_schema.sql" 2>&1 | sed 's/^/    /' || true
ntab="$(hdb_scalar "$HANA_TENANT" "SELECT COUNT(*) FROM SYS.TABLES WHERE SCHEMA_NAME='INAVIT_FIN'")"
[[ "$ntab" == "5" ]] || die "El esquema INAVIT_FIN no quedó completo (${ntab:-0}/5 tablas)"
ok "Esquema creado (5 tablas)"

log "Cargando datos en HANA"
HANA_PASSWORD="$HANA_MASTER_PASSWORD" docker run --rm \
  --network "$DOCKER_NETWORK" \
  -v "${DATA_DIR}:/data:ro,z" \
  -e HANA_PASSWORD -e HANA_HOST=hxehost -e HANA_SQL_PORT="$HANA_SQL_PORT" -e HANA_TENANT="$HANA_TENANT" -e HANA_USER=SYSTEM \
  inavit-datagen python load_hana.py --data /data \
  || die "Falló la carga a HANA. Si no conecta, revisa docs/troubleshooting.md (puerto SQL del tenant / TLS)."

cuenta_ok || die "Los conteos de HANA no coinciden con el manifiesto. Corre scripts/99-verify.sh para ver el detalle."
ok "HANA cargado y verificado contra el manifiesto"
