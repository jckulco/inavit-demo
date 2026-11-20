#!/usr/bin/env bash
# Ajustes de kernel que SAP HANA necesita en el HOST (vienen de tu repo sap-hana-datastage-lab).
# Los sysctls de memoria compartida no son "namespaced": NO se pueden pasar en `docker run`.
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CONF=/etc/sysctl.d/91-sap-hxe.conf
log "Escribiendo ${CONF}"
cat > "$CONF" <<'EOF'
# Ajustes requeridos por SAP HANA Express Edition
vm.max_map_count=2000000
vm.memory_failure_early_kill=1
fs.aio-max-nr=196608
kernel.shmmax=1073741824
kernel.shmall=8388608
EOF
sysctl --system >/dev/null
ok "sysctl aplicado (vm.max_map_count=$(cat /proc/sys/vm/max_map_count))"

# Chrony/NTP: CDC es sensible a desfases de reloj entre VMs
if command -v timedatectl >/dev/null; then
  sync="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo unknown)"
  [[ "$sync" == "yes" ]] && ok "Reloj sincronizado por NTP" || warn "Reloj no sincronizado por NTP (timedatectl set-ntp true)"
fi
