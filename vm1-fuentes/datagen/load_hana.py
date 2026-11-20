#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Carga los CSV de /data/hana en SAP HANA Express (esquema INAVIT_FIN) usando el
driver oficial hdbcli. Las tablas ya deben existir (sql/hana/01_schema.sql).

Se ejecuta dentro de un contenedor en la red de Docker donde vive HANA, por eso
el host por defecto es 'hxehost' (alias de red definido en el script de arranque).
"""
import argparse
import csv
import datetime as dt
import os
import sys
import time
from decimal import Decimal

from tables import HANA_LOAD_ORDER, HANA_SCHEMA, HANA_TABLES


def conv(kind, v):
    if v == "":
        return None
    if kind == "int":
        return int(v)
    if kind == "dec":
        return Decimal(v)
    if kind == "date":
        return dt.date.fromisoformat(v)
    return v


def connect(a):
    from hdbcli import dbapi
    intentos = []
    for port, tenant in ((a.port, None), (39017, a.tenant)):
        for cifrado in (False, True):
            kw = dict(address=a.host, port=port, user=a.user, password=a.password)
            if tenant:
                kw["databaseName"] = tenant
            if cifrado:
                kw.update(encrypt=True, sslValidateCertificate=False)
            intentos.append(kw)
    ultimo = None
    for kw in intentos:
        try:
            c = dbapi.connect(**kw)
            print("   conectado a %s:%s%s%s" % (kw["address"], kw["port"],
                  " (tenant %s)" % kw["databaseName"] if "databaseName" in kw else "",
                  " con TLS" if kw.get("encrypt") else ""), flush=True)
            return c
        except Exception as e:  # noqa: BLE001
            ultimo = e
    raise SystemExit("No se pudo conectar a HANA (%s). Último error: %s" % (a.host, ultimo))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="/data")
    ap.add_argument("--host", default=os.environ.get("HANA_HOST", "hxehost"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("HANA_SQL_PORT", 39041)))
    ap.add_argument("--tenant", default=os.environ.get("HANA_TENANT", "HXE"))
    ap.add_argument("--user", default=os.environ.get("HANA_USER", "SYSTEM"))
    ap.add_argument("--password", default=os.environ.get("HANA_PASSWORD", ""))
    ap.add_argument("--batch", type=int, default=20000)
    a = ap.parse_args()
    if not a.password:
        raise SystemExit("Falta HANA_PASSWORD")

    conn = connect(a)
    conn.setautocommit(False)
    cur = conn.cursor()
    t_ini = time.time()
    for tabla in HANA_LOAD_ORDER:
        cols = HANA_TABLES[tabla]
        sql = "INSERT INTO %s.%s (%s) VALUES (%s)" % (
            HANA_SCHEMA, tabla, ", ".join(c for c, _ in cols), ", ".join("?" for _ in cols))
        kinds = [k for _, k in cols]
        path = os.path.join(a.data, "hana", tabla + ".csv")
        total, lote, t0 = 0, [], time.time()
        with open(path, newline="", encoding="utf-8") as f:
            for r in csv.reader(f):
                lote.append(tuple(conv(k, v) for k, v in zip(kinds, r)))
                if len(lote) >= a.batch:
                    cur.executemany(sql, lote)
                    conn.commit()
                    total += len(lote)
                    lote = []
        if lote:
            cur.executemany(sql, lote)
            conn.commit()
            total += len(lote)
        print("   %-22s %10d filas en %.1fs" % (tabla, total, time.time() - t0), flush=True)
    cur.close()
    conn.close()
    print("== Carga HANA completa en %.0fs" % (time.time() - t_ini))
    return 0


if __name__ == "__main__":
    sys.exit(main())
