#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Valida los CSV generados (antes de cargarlos a las bases):
  - llaves primarias únicas
  - integridad referencial entre tablas y entre sistemas (Db2 <-> HANA)
  - validez de CURP/NSS
  - la "suciedad" sembrada está dentro de lo esperado
Termina con código != 0 si alguna verificación crítica falla.
"""
import argparse
import csv
import json
import os
import sys
from collections import Counter

import ids as I
from tables import DB2_TABLES, HANA_TABLES

fallos = []


def check(nombre, ok, detalle=""):
    print("  [%s] %s %s" % ("OK " if ok else "FALLA", nombre, detalle))
    if not ok:
        fallos.append(nombre)


def leer(path):
    with open(path, newline="", encoding="utf-8") as f:
        for r in csv.reader(f):
            yield r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="/data")
    a = ap.parse_args()
    d = a.data
    man = json.load(open(os.path.join(d, "manifest.json"), encoding="utf-8"))

    # idx de columnas
    def ix(tabla_def, tabla, col):
        return [c for c, _ in tabla_def[tabla]].index(col)

    print("== Filas por archivo vs manifiesto")
    for sistema, defs in (("db2", DB2_TABLES), ("hana", HANA_TABLES)):
        for t, cols in defs.items():
            n = 0
            for r in leer(os.path.join(d, sistema, t + ".csv")):
                if len(r) != len(cols):
                    check("%s.%s columnas" % (sistema, t), False, "fila con %d columnas (esperadas %d)" % (len(r), len(cols)))
                    break
                n += 1
            check("%s.%s filas" % (sistema, t), n == man["filas"]["%s.%s" % (sistema, t)], "(%d)" % n)

    print("== Patrones")
    patrones = set()
    est_p = Counter()
    for r in leer(os.path.join(d, "db2", "PATRON.csv")):
        patrones.add(r[0])
        est_p[r[10]] += 1
    check("PATRON PK única", len(patrones) == man["patrones"], "(%d)" % len(patrones))
    print("     estatus patrón:", dict(est_p))

    print("== Trabajadores")
    nss_set, curp_cnt = set(), Counter()
    curp_ok = curp_null = curp_mal = rfc_null = 0
    nss_ok = 0
    n_trab = 0
    patron_huerfano = 0
    sin_ap_materno = 0
    for r in leer(os.path.join(d, "db2", "TRABAJADOR.csv")):
        n_trab += 1
        nss_set.add(r[0])
        nss_ok += I.nss_valido(r[0])
        if not r[1]:
            curp_null += 1
        elif I.curp_valida(r[1]):
            curp_ok += 1
            curp_cnt[r[1]] += 1
        else:
            curp_mal += 1
        rfc_null += (not r[2])
        sin_ap_materno += (not r[5])
        patron_huerfano += (r[9] not in patrones)
    check("TRABAJADOR PK (NSS) única", len(nss_set) == n_trab, "(%d)" % n_trab)
    check("NSS con dígito verificador válido", nss_ok == n_trab)
    check("TRABAJADOR -> PATRON íntegro", patron_huerfano == 0)
    dup_curp = sum(1 for c, n in curp_cnt.items() if n > 1)
    print("     CURP válidas=%d nulas=%d truncadas/inválidas=%d | RFC nulo=%d | sin ap. materno=%d | CURP duplicadas=%d" % (
        curp_ok, curp_null, curp_mal, rfc_null, sin_ap_materno, dup_curp))
    check("CURP válidas >= 95%", curp_ok >= 0.95 * n_trab)
    check("hay duplicados por CURP sembrados", dup_curp > 0 or n_trab < 2000)

    print("== Subcuenta")
    sub_n = 0
    sub_orf = 0
    for r in leer(os.path.join(d, "db2", "SUBCUENTA_VIVIENDA.csv")):
        sub_n += 1
        sub_orf += (r[0] not in nss_set)
    check("SUBCUENTA 1:1 con TRABAJADOR", sub_n == n_trab and sub_orf == 0)

    print("== Aportaciones")
    ids_apo = set()
    orf_nss = orf_pat = 0
    dias_malos = cero = 0
    periodos = Counter()
    n_apo = 0
    for r in leer(os.path.join(d, "db2", "APORTACION.csv")):
        n_apo += 1
        ids_apo.add(int(r[0]))
        orf_nss += (r[1] not in nss_set)
        orf_pat += (r[2] not in patrones)
        periodos[r[3]] += 1
        dias_malos += (int(r[5]) > 62)
        cero += (float(r[6]) == 0.0)
    check("APORTACION PK única", len(ids_apo) == n_apo, "(%d)" % n_apo)
    check("APORTACION -> TRABAJADOR íntegro", orf_nss == 0)
    check("APORTACION -> PATRON íntegro", orf_pat == 0)
    check("IDs < 100,000,000 (reservado para la secuencia de la demo en vivo)", max(ids_apo) < 100000000)
    print("     DQ sembrada: días>62=%d, monto=0=%d | períodos: %s" % (dias_malos, cero, ", ".join(
        "%s:%d" % (k, periodos[k]) for k in sorted(periodos))))

    print("== Créditos (HANA) vs Db2")
    cred_ids = set()
    huerfanos = espacios = 0
    estatus = Counter()
    n_cred = 0
    pat_orf = 0
    morosos_por_ent = Counter()
    por_ent = Counter()
    for r in leer(os.path.join(d, "hana", "CREDITO.csv")):
        n_cred += 1
        cred_ids.add(int(r[0]))
        nss_c = r[1]
        if nss_c != nss_c.strip():
            espacios += 1
            nss_c = nss_c.strip()
        huerfanos += (nss_c not in nss_set)
        pat_orf += (r[8] not in patrones)
        e = r[15].strip().upper()
        estatus[r[15]] += 1
        por_ent[r[6]] += 1
        if e in ("MOROSO", "CARTERA_VENCIDA"):
            morosos_por_ent[r[6]] += 1
    check("CREDITO PK única", len(cred_ids) == n_cred, "(%d)" % n_cred)
    pct_h = 100.0 * huerfanos / max(1, n_cred)
    check("créditos huérfanos (NSS no está en Db2) entre 0.1% y 1%", n_cred < 500 or 0.1 <= pct_h <= 1.0, "(%.2f%%)" % pct_h)
    check("CREDITO -> PATRON íntegro", pat_orf == 0)
    print("     NSS con espacios=%d | estatus (crudo): %s" % (espacios, dict(estatus)))
    top = sorted(((100.0 * morosos_por_ent[k] / por_ent[k], k) for k in por_ent if por_ent[k] >= 30), reverse=True)[:5]
    print("     % mora más alta por entidad:", ", ".join("%s=%.1f%%" % (k, p) for p, k in top))

    print("== Pagos y cobranza")
    pago_orf = n_pago = 0
    ids_pago = set()
    for r in leer(os.path.join(d, "hana", "PAGO.csv")):
        n_pago += 1
        ids_pago.add(int(r[0]))
        pago_orf += (int(r[1]) not in cred_ids)
    check("PAGO PK única", len(ids_pago) == n_pago, "(%d)" % n_pago)
    check("PAGO -> CREDITO íntegro", pago_orf == 0)
    cob_orf = 0
    for r in leer(os.path.join(d, "hana", "COBRANZA.csv")):
        cob_orf += (int(r[1]) not in cred_ids)
    check("COBRANZA -> CREDITO íntegro", cob_orf == 0)

    print("== KPIs para la demo (manifest.json)")
    print(json.dumps(man["kpis_demo"], ensure_ascii=False, indent=2))
    print("     patrones omisos: %d" % man["patrones_omisos"])

    print()
    if fallos:
        print("RESULTADO: %d verificación(es) fallaron: %s" % (len(fallos), ", ".join(fallos)))
        return 1
    print("RESULTADO: todas las verificaciones pasaron.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
