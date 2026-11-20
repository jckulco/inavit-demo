#!/usr/bin/env bash
# Demo en vivo del momento "tiempo real": inserta aportaciones nuevas en Db2 y actualiza
# la subcuenta de cada trabajador. IIDR debe replicarlas a SQL Server en segundos.
# Uso: demo-live-insert.sh [-n cantidad] [-d segundos_entre_inserts]
#   Cada aportación queda marcada ORIGEN='D' para reconocerla fácil en el destino.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_env

N=5; DELAY=1
while getopts "n:d:" o; do
  case "$o" in n) N="$OPTARG" ;; d) DELAY="$OPTARG" ;; *) die "Uso: $0 [-n cantidad] [-d segundos]" ;; esac
done
[[ "$N" =~ ^[0-9]+$ && "$DELAY" =~ ^[0-9]+$ ]] || die "-n y -d deben ser enteros"

PERIODO="$(printf '%s%02d' "$(date +%Y)" "$(( ($(date +%-m) + 1) / 2 ))")"
log "Insertando ${N} aportaciones del período ${PERIODO} en Db2 (${DB2_DBNAME})"

mapfile -t ROWS < <(db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null && db2 -x \"SELECT NSS FROM INAVIT_APO.TRABAJADOR WHERE ESTATUS='A' ORDER BY RAND() FETCH FIRST ${N} ROWS ONLY\"" | tr -d '\r ' | grep -E '^[0-9]{11}$' || true)
(( ${#ROWS[@]} > 0 )) || die "No se pudieron elegir trabajadores activos"

for nss in "${ROWS[@]}"; do
  db2_sh "db2 connect to ${DB2_DBNAME} >/dev/null \
    && db2 \"INSERT INTO INAVIT_APO.APORTACION (APORTACION_ID, NSS, REGISTRO_PATRONAL, PERIODO, SALARIO_DIARIO_INTEGRADO, DIAS_COTIZADOS, MONTO_APORTACION, FECHA_PAGO, ORIGEN, FECHA_REGISTRO) SELECT NEXT VALUE FOR INAVIT_APO.SEQ_APORTACION, NSS, REGISTRO_PATRONAL, '${PERIODO}', SALARIO_DIARIO_INTEGRADO, 61, ROUND(SALARIO_DIARIO_INTEGRADO*61*0.05,2), CURRENT DATE, 'D', CURRENT TIMESTAMP FROM INAVIT_APO.TRABAJADOR WHERE NSS='${nss}'\" >/dev/null \
    && db2 \"UPDATE INAVIT_APO.SUBCUENTA_VIVIENDA SET SALDO_PESOS = SALDO_PESOS + (SELECT MONTO_APORTACION FROM INAVIT_APO.APORTACION WHERE NSS='${nss}' AND ORIGEN='D' ORDER BY APORTACION_ID DESC FETCH FIRST 1 ROW ONLY), BIMESTRES_COTIZADOS = BIMESTRES_COTIZADOS + 1, FECHA_ULTIMA_APORTACION = CURRENT DATE WHERE NSS='${nss}'\" >/dev/null" \
    || die "Falló el insert para NSS ${nss}"
  monto="$(db2_scalar "SELECT MONTO_APORTACION FROM INAVIT_APO.APORTACION WHERE NSS='${nss}' AND ORIGEN='D' ORDER BY APORTACION_ID DESC FETCH FIRST 1 ROW ONLY")"
  ok "NSS ${nss} · período ${PERIODO} · aportación \$${monto}"
  sleep "$DELAY"
done
log "Listo. En el destino: SELECT * FROM INAVIT_APO.APORTACION WHERE ORIGEN='D' ORDER BY APORTACION_ID DESC"
