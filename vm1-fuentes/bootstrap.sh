#!/usr/bin/env bash
# =============================================================================
# INAVIT · VM1 · Fuentes de datos: SAP HANA Express + Db2, pobladas con datos de México.
# Uso:  sudo bash bootstrap.sh [--force-data] [--skip-preflight]
# Es idempotente: si algo falla, corrige y vuelve a correrlo; salta lo ya hecho.
# Tiempo total esperado: 25-45 min (la mayor parte es el primer arranque de HANA).
# =============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
S=scripts

FORCE=""; SKIP_PRE=0
for a in "$@"; do
  case "$a" in
    --force-data)     FORCE="--force" ;;
    --skip-preflight) SKIP_PRE=1 ;;
    *) echo "Opción desconocida: $a"; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi

T0=$(date +%s)
step() { printf '\n\033[1;35m━━ %s\033[0m\n' "$*"; }

step "0/8 Configuración (.env)";                 bash $S/00-init-env.sh
(( SKIP_PRE )) || { step "0/8 Preflight";        bash $S/00-preflight.sh; }
step "1/8 Ajustes de kernel del host";           bash $S/01-setup-host.sh
step "2/8 Arrancar HANA y Db2 (en paralelo)";    bash $S/02-hana-up.sh start; bash $S/03-db2-up.sh start
step "3/8 Generar datos sintéticos (mientras HANA/Db2 se inicializan)"; bash $S/04-generate-data.sh ${FORCE}
step "4/8 Esperar HANA";                         bash $S/02-hana-up.sh wait
step "5/8 Esperar Db2 y crear esquema";          bash $S/03-db2-up.sh wait
step "6/8 Cargar HANA";                          bash $S/05-load-hana.sh ${FORCE}
step "6/8 Cargar Db2";                           bash $S/06-load-db2.sh ${FORCE}
step "7/8 Log de archivo en Db2 (requisito CDC)"; bash $S/07-db2-archive-logging.sh
step "8/8 Verificación final";                   bash $S/99-verify.sh

printf '\n\033[1;32mListo en %d min.\033[0m\n' $(( ($(date +%s) - T0) / 60 ))
