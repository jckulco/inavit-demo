#!/usr/bin/env bash
# =============================================================================
# INAVIT · VM5 · respaldo diario del export de Cognos
# Copia el ZIP que genera el export programado de Cognos (02:00 UTC), con fecha,
# genera su SHA-256, avisa si el export es viejo y conserva las últimas 14 copias.
#
# RECONSTRUIDO a partir de la descripción del script original de VM5
# (/usr/local/bin/backup_inavit.sh). Compáralo con el de tu VM antes de reemplazarlo.
#
# Instalación (root):
#   install -m 755 backup_inavit.sh /usr/local/bin/backup_inavit.sh
#   crontab -e   ->   30 2 * * * /usr/local/bin/backup_inavit.sh >> /var/log/backup_inavit.log 2>&1
# =============================================================================
set -euo pipefail

SRC="${SRC:-/mnt/second/ibm/cognos/analytics/deployment/INAVIT_export.zip}"
DEST="${DEST:-/mnt/second/backups/inavit}"
OWNER="${OWNER:-itzuser}"        # usuario que descarga los respaldos por scp
KEEP="${KEEP:-14}"               # copias a conservar
MAX_AGE_H="${MAX_AGE_H:-26}"     # aviso si el export tiene más horas que esto

ts() { date '+%Y-%m-%d %H:%M:%S'; }

if [[ ! -f "$SRC" ]]; then
  echo "$(ts) ERROR: no existe $SRC (¿corrió el export programado de Cognos?)"
  exit 1
fi

age_h=$(( ( $(date +%s) - $(stat -c %Y "$SRC") ) / 3600 ))
if (( age_h > MAX_AGE_H )); then
  echo "$(ts) AVISO: el export tiene ${age_h} h (más de ${MAX_AGE_H}); revisa la programación en Cognos"
fi

mkdir -p "$DEST"
out="$DEST/INAVIT_export_$(date +%Y%m%d_%H%M).zip"
cp -p "$SRC" "$out"
( cd "$DEST" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256" )

# Rotación: conserva las últimas $KEEP copias (y sus .sha256)
ls -1t "$DEST"/INAVIT_export_*.zip 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
  rm -f "$old" "$old.sha256"
done

# Permisos para que scp funcione sin "Permission denied"
chmod 755 "$(dirname "$DEST")" "$DEST"
chown -R "$OWNER" "$DEST"

echo "$(ts) OK: $out ($(du -h "$out" | cut -f1)), $(ls -1 "$DEST"/INAVIT_export_*.zip | wc -l) copias"
