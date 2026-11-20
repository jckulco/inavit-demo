#!/usr/bin/env bash
# Crea .env a partir de .env.example y genera contraseñas seguras la primera vez.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ -f "$ENV_FILE" ]]; then
  ok ".env ya existe ($ENV_FILE) — no se modifica"
  exit 0
fi

gen_pw() {
  # 'Inav' + 14 alfanuméricos + '9x'  => mayúscula, minúscula y número garantizados
  local r; r="$(head -c 256 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 14)"
  printf 'Inav%s9x' "$r"
}

cp "$ROOT_DIR/.env.example" "$ENV_FILE"
chmod 600 "$ENV_FILE"
sed -i "s|^HANA_MASTER_PASSWORD=.*|HANA_MASTER_PASSWORD=$(gen_pw)|" "$ENV_FILE"
sed -i "s|^HANA_APP_PASSWORD=.*|HANA_APP_PASSWORD=$(gen_pw)|"       "$ENV_FILE"
sed -i "s|^DB2_PASSWORD=.*|DB2_PASSWORD=$(gen_pw)|"                 "$ENV_FILE"
ok "Creado $ENV_FILE con contraseñas generadas (permisos 600)."
log "Revísalo y ajusta rutas/volumen si lo necesitas. Las contraseñas están en ese archivo."
