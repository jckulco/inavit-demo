# 00 · Accesos y túneles

Todo el trabajo se hace desde una laptop con DBeaver y un navegador, a través de túneles SSH hacia cada VM.
Ningún puerto de base de datos se expone a internet, salvo la ruta de DataStage hacia SQL Server
si DataStage corre en la nube (ver [`03-staging-vm3.md`](03-staging-vm3.md)).

## 1. Inventario

Copia `config/hosts.env.example` a `config/hosts.env` y llénalo. Ese archivo está en `.gitignore`.

| Servicio | Host | Puerto | Base / ruta | Usuario |
|---|---|---|---|---|
| SAP HANA Express (tenant HXE) | VM1 | 39041 | esquema `INAVIT_FIN` | `INAVIT_DS` (lectura) o `SYSTEM` |
| Db2 Community | VM1 | 50000 | base `INAVITDB`, esquema `INAVIT_APO` | `db2inst1` |
| SQL Server 2019 | VM3 | 1433 | base `INAVIT_STG`, esquema `INAVIT_APO` | `sa` o un login de lectura |
| PostgreSQL | VM3 | 5432 | base `inavit_stg`, esquema `hana_raw` | el de tu instalación |
| Netezza SaaS | Azure (East US 2) | 5480 | base de la instancia, esquema `INAVIT_DW` | usuario de la instancia |
| Consola watsonx.data | VM4 | 6443 | `https://localhost:6443/` | el del instalador |
| Consola MinIO | VM4 | 9001 | `http://localhost:9001/` | credenciales de MinIO del instalador |
| Presto | VM4 | 8443 | motor `presto-01` | — |
| Cognos Analytics | VM5 | 9300 | `http://localhost:9300/bi/` | administrador de Cognos |

Las contraseñas de VM1 se generan en `vm1-fuentes/.env` al instalar (permisos 600).

## 2. Túneles

Agrega `config/ssh_config.example` a `~/.ssh/config` (con tus hosts y llaves) y abre cada túnel:

```bash
chmod 600 ~/.ssh/<llave>.pem
ssh -fN inavit-vm1    # 39041, 50000
ssh -fN inavit-vm3    # 1433, 5432
ssh -fN inavit-vm4    # 6443, 9001, 9000, 8443
ssh -fN inavit-vm5    # 9300
# cerrar todos:
pkill -f "ssh -fN inavit-"
```

Sin `~/.ssh/config`, el equivalente para VM4 es:

```bash
ssh -i <llave>.pem -N -L 6443:localhost:6443 -L 9001:localhost:9001 \
    -L 9000:localhost:9000 -L 8443:localhost:8443 itzuser@<ip-vm4>
```

Si un puerto local ya está ocupado (por ejemplo 6443 por Docker Desktop), cambia el lado izquierdo:
`-L 7443:localhost:6443` y abre `https://localhost:7443/`.

## 3. VM4: los port-forwards viven en la VM

En watsonx.data Developer Edition los servicios están dentro de Kubernetes (KIND, namespace `wxd`).
El túnel SSH llega a `localhost` de VM4, y ahí `kubectl port-forward` los publica.
Esos procesos se pierden al reiniciar la VM. Para levantarlos:

```bash
sudo bash watsonx-data/start_forwards.sh      # copia de /opt/repos/wxd-remote-access/start_forwards.sh
```

Detalle en [`07-watsonx-data.md`](07-watsonx-data.md).

## 4. Conexiones en DBeaver

En el proyecto original se organizaron así (carpeta `DEMOS/INAVIT-Techday`):

```
Orígenes   HXE (localhost:39041) · INAVITDB (localhost:50000)
Destinos   INAVIT_STG (localhost:1433) · inavit_stg (localhost:5432)
Netezza SaaS  conexión a la instancia (puerto 5480)
```

Deja Auto-commit activado en Db2 para que los `INSERT` de la demo en vivo se confirmen al ejecutar.
