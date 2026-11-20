#!/usr/bin/env bash
# =============================================================================
# INAVIT · VM4 · port-forwards de watsonx.data Developer Edition (KIND, namespace wxd)
# Publica en 0.0.0.0 de la VM los servicios que el túnel SSH de la laptop necesita.
# Los procesos kubectl se pierden al reiniciar la VM: vuelve a correr este script.
#
# RECONSTRUIDO de /opt/repos/wxd-remote-access/start_forwards.sh del proyecto original.
# Uso (root):  bash start_forwards.sh            logs en /tmp/pf-<nombre>.log
# =============================================================================
set -euo pipefail
NS="${NS:-wxd}"

start() {   # start <nombre> <puerto-local> <servicio> <puerto-servicio>
  local name="$1" lport="$2" svc="$3" sport="$4"
  nohup kubectl port-forward -n "$NS" --address 0.0.0.0 "svc/$svc" "$lport:$sport" \
    > "/tmp/pf-$name.log" 2>&1 &
  echo "  $name: 0.0.0.0:$lport -> $svc:$sport (pid $!)"
}

echo "Deteniendo port-forwards anteriores..."
pkill -f "kubectl port-forward -n $NS" || true
sleep 1

echo "Levantando port-forwards:"
start console   6443 lhconsole-ui-svc   443
start minio-ui  9001 ibm-lh-minio-svc   9001
start minio-api 9000 ibm-lh-minio-svc   9000
start presto    8443 ibm-lh-presto-svc  8443
# Opcional: Hive Metastore (thrift, sin interfaz web)
# start mds 8381 ibm-lh-mds-thrift-svc 8381

sleep 3
ss -tlnp | grep -E ':(6443|9001|9000|8443)\b' || echo "AVISO: algún puerto no quedó escuchando; revisa /tmp/pf-*.log"
