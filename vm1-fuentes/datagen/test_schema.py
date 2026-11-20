#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verifica que el orden y los nombres de columnas de tables.py coincidan con los
CREATE TABLE de sql/db2/01_schema.sql y sql/hana/01_schema.sql.
Uso: python3 datagen/test_schema.py   (desde la raíz del repo)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tables import DB2_SCHEMA, DB2_TABLES, HANA_SCHEMA, HANA_TABLES  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def columnas_ddl(sql, esquema, tabla):
    m = re.search(r"CREATE\s+(?:COLUMN\s+)?TABLE\s+%s\.%s\s*\((.*?)\n\)\s*;" % (esquema, tabla), sql, re.S | re.I)
    if not m:
        return None
    cols = []
    for linea in m.group(1).splitlines():
        linea = linea.split("--")[0].strip().rstrip(",")
        if not linea or linea.upper().startswith(("CONSTRAINT", "PRIMARY KEY")):
            continue
        cols.append(linea.split()[0].strip('"').upper())
    return cols


def main():
    malos = 0
    for ruta, esquema, defs in (("sql/db2/01_schema.sql", DB2_SCHEMA, DB2_TABLES),
                                ("sql/hana/01_schema.sql", HANA_SCHEMA, HANA_TABLES)):
        sql = open(os.path.join(RAIZ, ruta), encoding="utf-8").read()
        for tabla, cols in defs.items():
            ddl = columnas_ddl(sql, esquema, tabla)
            esperado = [c for c, _ in cols]
            ok = ddl == esperado
            print("[%s] %s.%s" % ("OK " if ok else "FALLA", esquema, tabla))
            if not ok:
                malos += 1
                print("   tables.py:", esperado)
                print("   DDL      :", ddl)
    return 1 if malos else 0


if __name__ == "__main__":
    sys.exit(main())
