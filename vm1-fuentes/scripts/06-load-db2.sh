#!/usr/bin/env bash
# Carga los CSV en Db2 (LOAD ... NONRECOVERABLE: rápido, funciona con y sin log de archivo).
# Uso: 06-load-db2.sh [--force]
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
load_manifest
FORCE=0; [[ "${1:-}" == "--force" ]] && FORCE=1

container_running "$DB2_CONTAINER" || die "Db2 no está en ejecución"
TABLAS=(PATRON TRABAJADOR SUBCUENTA_VIVIENDA APORTACION)

for t in "${TABLAS[@]}"; do
  var="ROWS_DB2_${t}"; esperado="${!var}"
  n="$(db2_scalar "SELECT COUNT(*) FROM INAVIT_APO.${t}" || true)"
  if (( ! FORCE )) && [[ "$n" == "$esperado" ]]; then
    ok "INAVIT_APO.${t}: ya tiene ${n} filas"
    continue
  fi
  log "LOAD ${t} (${esperado} filas)"
  out="$(db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null && db2 \"LOAD FROM /inavit_data/db2/${t}.csv OF DEL MESSAGES /tmp/load_${t}.msg REPLACE INTO INAVIT_APO.${t} NONRECOVERABLE\"" 2>&1)" \
    || { printf '%s\n' "$out" | tail -n 25; db2_sh "cat /tmp/load_${t}.msg 2>/dev/null | tail -n 30" || true; die "Falló el LOAD de ${t}"; }
  printf '%s\n' "$out" | grep -E 'rows (read|loaded|rejected|skipped)' | sed 's/^/    /' || true
  db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null && db2 \"RUNSTATS ON TABLE INAVIT_APO.${t} WITH DISTRIBUTION AND INDEXES ALL\"" >/dev/null 2>&1 || warn "RUNSTATS falló en ${t}"
  n="$(db2_scalar "SELECT COUNT(*) FROM INAVIT_APO.${t}")"
  [[ "$n" == "$esperado" ]] || die "INAVIT_APO.${t}: ${n} filas, se esperaban ${esperado}"
  ok "INAVIT_APO.${t}: ${n} filas"
done
ok "Db2 cargado y verificado contra el manifiesto"
