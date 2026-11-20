# Cognos · respaldo y restauración

Guía completa: [`docs/06-cognos.md`](../docs/06-cognos.md).

| Archivo | Uso |
|---|---|
| `backup_inavit.sh` | Copia diaria del export con SHA-256 y rotación de 14 (va en `/usr/local/bin/` de VM5) |
| `crontab.example` | Línea de cron (02:30, después del export de las 02:00 UTC) |
| `export/` | Coloca aquí `INAVIT_export.zip` localmente; los `.zip` no se suben a git |
