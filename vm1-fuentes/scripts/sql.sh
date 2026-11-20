#!/usr/bin/env bash
# Atajo para consultas rápidas.
#   bash scripts/sql.sh hana "SELECT COUNT(*) FROM INAVIT_FIN.CREDITO"
#   bash scripts/sql.sh db2  "SELECT COUNT(*) FROM INAVIT_APO.APORTACION"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
[[ $# -eq 2 ]] || die "Uso: $0 hana|db2 \"<SQL sin comillas dobles>\""
case "$1" in
  hana) hdb_run "$HANA_TENANT" -j "$2" ;;
  db2)  db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null && db2 \"$2\"" ;;
  *)    die "Primer argumento: hana | db2" ;;
esac
