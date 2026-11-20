#!/usr/bin/env bash
# Verificación final de la VM1: contenedores, datos, log de archivo y parámetros de conexión.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env
load_manifest

FALLAS=0
pasa()  { printf '%s  PASS%s %s\n' "$C_G" "$C_0" "$*"; }
falla() { printf '%s  FAIL%s %s\n' "$C_R" "$C_0" "$*"; FALLAS=$((FALLAS + 1)); }
chk()   { if [[ "$1" == "$2" ]]; then pasa "$3"; else falla "$3 (obtenido: '${1:-}', esperado: '$2')"; fi; }

log "Verificación VM1"

echo "── Contenedores"
for c in "$HANA_CONTAINER" "$DB2_CONTAINER"; do
  container_running "$c" && pasa "$c en ejecución" || falla "$c NO está en ejecución"
done

echo "── SAP HANA Express (esquema INAVIT_FIN)"
chk "$(hdb_scalar "$HANA_TENANT" 'SELECT 1 FROM DUMMY')" "1" "tenant ${HANA_TENANT} responde"
for t in CAT_ENTIDAD CAT_PRODUCTO_CREDITO CREDITO PAGO COBRANZA; do
  var="ROWS_HANA_${t}"
  chk "$(hdb_scalar "$HANA_TENANT" "SELECT COUNT(*) FROM INAVIT_FIN.${t}")" "${!var}" "INAVIT_FIN.${t} = ${!var} filas"
done
app="$(docker exec -u hxeadm -e "HP=${HANA_APP_PASSWORD}" "$HANA_CONTAINER" bash -lc \
  'hdbsql -i "$1" -d "$2" -u "$3" -p "$HP" -a -x -j "SELECT COUNT(*) FROM INAVIT_FIN.CAT_ENTIDAD"' \
  _ "$HANA_INSTANCE" "$HANA_TENANT" "$HANA_APP_USER" </dev/null 2>/dev/null | tr -d '"\r ' | head -n1 || true)"
chk "$app" "32" "usuario ${HANA_APP_USER} puede leer INAVIT_FIN"

echo "── Db2 (esquema INAVIT_APO)"
for t in PATRON TRABAJADOR SUBCUENTA_VIVIENDA APORTACION; do
  var="ROWS_DB2_${t}"
  chk "$(db2_scalar "SELECT COUNT(*) FROM INAVIT_APO.${t}")" "${!var}" "INAVIT_APO.${t} = ${!var} filas"
done
chk "$(db2_scalar "SELECT COUNT(*) FROM SYSCAT.TABCONST WHERE TABSCHEMA='INAVIT_APO' AND TYPE='P'")" "4" "las 4 tablas tienen llave primaria (requisito de CDC)"
chk "$(db2_scalar "SELECT COUNT(*) FROM SYSCAT.SEQUENCES WHERE SEQSCHEMA='INAVIT_APO'")" "1" "secuencia SEQ_APORTACION existe"
cod="$(db2_sh "db2 get db cfg for ${DB2_DBNAME} | grep -i 'Database code set'" 2>/dev/null | tr -d '\r' || true)"
[[ "$cod" == *"UTF-8"* ]] && pasa "base en UTF-8" || falla "la base no es UTF-8: ${cod}"
arch="$(db2_sh "db2 get db cfg for ${DB2_DBNAME} | grep -i 'LOGARCHMETH1'" 2>/dev/null | tr -d '\r' || true)"
[[ "$arch" == *"DISK:"* ]] && pasa "log de archivo activo (LOGARCHMETH1)" || falla "log de archivo NO activo: corre scripts/07-db2-archive-logging.sh"

echo
echo "── Resumen de la historia de la demo (manifest.json)"
if command -v python3 >/dev/null; then
  python3 - "${DATA_DIR}/manifest.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], encoding="utf-8")); k = m["kpis_demo"]
print("   Períodos aportaciones : %s a %s (%d bimestres) | al corte %s" % (m["periodo_inicial"], m["periodo_final"], m["bimestres"], m["as_of"]))
print("   Patrones omisos       : %d de %d" % (m["patrones_omisos"], m["patrones"]))
for g, n in k["creditos_por_grupo"].items():
    print("   Mora grupo %-22s: %5.1f%% (%d de %d créditos)" % (g, 100.0 * k["morosos_por_grupo"][g] / max(1, n), k["morosos_por_grupo"][g], n))
print("   Derechohabientes precalificados (regla de ejemplo): %d" % k["precalificados"])
PY
fi

echo
echo "── Parámetros de conexión (dentro de la VM1; desde otras VMs vía túnel SSH)"
cat <<EOF
   SAP HANA  : host localhost · puerto ${HANA_SQL_PORT} · tenant ${HANA_TENANT} · usuario ${HANA_APP_USER} · esquema INAVIT_FIN
   Db2       : host localhost · puerto ${DB2_PORT} · base ${DB2_DBNAME} · usuario db2inst1 · esquema INAVIT_APO
   Contraseñas: ${ENV_FILE}
   Db2 (versión): $(db2_sh 'db2level | grep -i "Informational tokens"' 2>/dev/null | tr -d '\r' | sed 's/  */ /g' || true)
EOF

echo
if (( FALLAS > 0 )); then die "${FALLAS} verificación(es) fallaron."; fi
ok "VM1 lista: HANA y Db2 pobladas. Siguiente fase: red/túneles y motor de replicación de Db2."
