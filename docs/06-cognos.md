# 06 · Cognos Analytics 12.1.3 (VM5)

El tablero **"INAVIT - Cartera y morosidad"** usa el módulo de datos **INAVIT_DM** sobre las vistas de
Netezza y tiene tres pestañas: *Cartera y morosidad*, *Patrones omisos* y *Precalificados*.
Acceso por túnel SSH en `http://localhost:9300/bi/`.

## Instalación (resumen del proyecto original)

- Cognos 12.1.3 en RHEL, instalado con el instalador silencioso y archivo de respuestas (`-f`).
- Content Store en Db2 (Docker) con JDBC tipo 4 (`server=localhost:50000`).
- Servicio de `systemd` para arrancar Cognos con la VM.
- Acceso solo por túnel SSH al puerto 9300 (llave con `chmod 600`).
- Driver JDBC de Netezza en la carpeta `drivers/` de la instalación de Cognos, si no lo tienes ya.

## Restaurar el tablero en un ambiente nuevo

Requisitos: Netezza con el esquema `INAVIT_DW` y sus vistas, el ZIP del export y su contraseña.

1. **Conexión de datos.** En *Manage → Data server connections* crea la conexión **INAVIT_DW** a Netezza
   (host, puerto 5480, base, usuario). El export no incluye contraseñas de conexiones, así que siempre se
   recrea a mano. Usa el mismo nombre para que el módulo la encuentre.
2. **Copia el ZIP** a la carpeta de deployment del servidor:
   `/mnt/second/ibm/cognos/analytics/deployment/INAVIT_export.zip` (en VM5).
   El export no tiene botón de descarga ni de carga; se copia por SSH.
3. **Importa.** *Administration → Content Administration → Import*, selecciona el archivo, escribe la
   contraseña del export y marca la carpeta INAVIT.
4. **Para no sobrescribir** contenido existente: cambia el *Target name* y activa
   *Assign new IDs during import*.
5. **Verifica.** Abre el tablero, revisa las tres pestañas y las cifras de referencia
   ([`10-cifras-de-referencia.md`](10-cifras-de-referencia.md)); en *Selected sources* confirma que apunta al
   módulo importado.

La importación se probó el 18 de noviembre de 2026 a una carpeta aparte: *Succeeded*, 0 objetos fallidos.
Falta probar el paso 1 en un ambiente realmente nuevo.

## Detalles del módulo que hay que conservar

**Tabla "V Precalificados" con SQL nativo.** Es una tabla personalizada con *SQL Type = Native SQL*:

```sql
SELECT * FROM INAVIT_DW.V_PRECALIFICADOS_DASH
```

Se usa SQL nativo porque Cognos guardaba en caché los metadatos de `V_PRECALIFICADOS` (12 de 16 columnas) y
*IBM Query SQL* fallaba con `XQE-MSR-0023`. Si se recrea el módulo, debe hacerse igual, y la vista
`V_PRECALIFICADOS_DASH` no se debe borrar.

| Cálculo | Tabla | Definición |
|---|---|---|
| `Patron Detalle` | V Patron Omiso | `[Razon Social] \|\| ' · ' \|\| [Entidad] \|\| ' · ' \|\| [Sector]` |
| `Num Precalificados` | V Precalificados | `if ([Nss] is not null) then (1) else (0)`, medida (suma) |
| `Grupo patron`, `Num Patrones` | V Patron Omiso | Cálculos auxiliares de la pestaña 2 |

`Patron Detalle` existe para evitar el error *"Estimated number of cells exceeds 100000"* en la tabla
Top 10 de patrones.

**Diseño.** Página de 1280 px con la misma cuadrícula en las pestañas 1 y 3: título en (20, 10) de 1240 × 60;
cuatro KPI de 295 × 100 en y = 80; cuatro gráficas de 610 × 330 en (20, 200), (650, 200), (20, 550) y
(650, 550). Paleta: `0F62FE` (azul), `A8A8A8` (gris) y `DA1E28` (rojo).

## Export y respaldo automático

1. **Export.** *Administration → Content Administration → New export* llamado `INAVIT_export`, con cifrado y la
   carpeta INAVIT. El contenido debe estar en *Team content*: lo que está en *My content* no entra al export.
   Guarda la contraseña en un gestor de contraseñas; sin ella el ZIP no se importa.
2. **Programación.** Programa ese export (no la especificación de import) diario a las **02:00, hora del servidor
   (UTC)**.
3. **Respaldo en VM5.** [`cognos/backup_inavit.sh`](../cognos/backup_inavit.sh) copia el ZIP con fecha a
   `/mnt/second/backups/inavit/`, genera su SHA-256, avisa si el export tiene más de 26 horas y conserva 14 copias.
   Se ejecuta con el cron de [`cognos/crontab.example`](../cognos/crontab.example) (02:30).

```bash
install -m 755 cognos/backup_inavit.sh /usr/local/bin/backup_inavit.sh
crontab -e     # pega la línea de crontab.example
# comprobar al día siguiente:
tail /var/log/backup_inavit.log
ls -lh /mnt/second/backups/inavit/
# descargar a la laptop:
scp itzuser@<vm5>:/mnt/second/backups/inavit/INAVIT_export_*.zip .
```

El script del repositorio está reconstruido de la descripción del original; compáralo con
`/usr/local/bin/backup_inavit.sh` de tu VM5.
