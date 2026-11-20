#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generador de datos SINTÉTICOS para la demo INAVIT.

Produce CSV (sin encabezado, UTF-8) listos para cargarse en:
  - Db2   (esquema INAVIT_APO): PATRON, TRABAJADOR, SUBCUENTA_VIVIENDA, APORTACION
  - HANA  (esquema INAVIT_FIN): CAT_ENTIDAD, CAT_PRODUCTO_CREDITO, CREDITO, PAGO, COBRANZA

Reglas de coherencia entre ambos sistemas:
  * NSS, CURP, RFC y REGISTRO_PATRONAL son los mismos en Db2 y en HANA.
  * Una semilla fija hace la generación reproducible.

Calidad de datos "sembrada" a propósito (para los flujos de DataStage):
  duplicados por CURP con distinto NSS, nombres con mayúsculas/acentos
  inconsistentes, CURP/RFC nulos o truncados, fechas de nacimiento
  inválidas, días cotizados fuera de rango, créditos huérfanos (NSS que no
  existe en Db2), estatus de crédito con variantes de captura, etc.

Historia de negocio incluida:
  * ~7% de los patrones dejan de aportar (omisos); sus trabajadores o
    cambian de patrón tras un hueco o quedan sin aportar.
  * Los acreditados cuyo patrón dejó de aportar tienen mucha más morosidad.
  * Hay trabajadores sin crédito con saldo y antigüedad suficientes
    (derechohabientes precalificados).
"""
import argparse
import bisect
import calendar
import csv
import json
import math
import os
import random
import sys
import time
from datetime import date, timedelta

import catalogs as C
import ids as I
from tables import DB2_TABLES, HANA_TABLES

MIN_SDI = 329.30  # piso aproximado del salario diario integrado (ficticio)
TASA_APORTACION = 0.05
PRECALIF_SALDO = 90000.0       # solo para el KPI del manifiesto; Netezza definirá su propia regla
PRECALIF_BIMESTRES = 24


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
def add_months(d, n):
    m = d.month - 1 + n
    y = d.year + m // 12
    m = m % 12 + 1
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))


def last_day(y, m):
    return date(y, m, calendar.monthrange(y, m)[1])


def build_periods(as_of, n):
    """n bimestres consecutivos; el último es el más reciente cuya fecha
    límite de pago (día 17 del mes siguiente) ya pasó."""
    y, b = as_of.year, (as_of.month + 1) // 2
    while True:
        end = last_day(y, 2 * b)
        due = end + timedelta(days=17)
        if due <= as_of:
            break
        b -= 1
        if b == 0:
            b, y = 6, y - 1
    periods = []
    for _ in range(n):
        start = date(y, 2 * b - 1, 1)
        end = last_day(y, 2 * b)
        periods.append({"label": "%d%02d" % (y, b), "start": start, "end": end,
                        "days": (end - start).days + 1})
        b -= 1
        if b == 0:
            b, y = 6, y - 1
    periods.reverse()
    return periods


def wpick(rng, items, cum):
    return items[min(bisect.bisect_left(cum, rng.random() * cum[-1]), len(items) - 1)]


def money(x):
    return "%.2f" % x


class Out:
    def __init__(self, path):
        self.f = open(path, "w", newline="", encoding="utf-8")
        self.w = csv.writer(self.f, lineterminator="\n")
        self.n = 0

    def row(self, r):
        self.w.writerow(r)
        self.n += 1

    def close(self):
        self.f.close()


def ensucia_texto(s, rng):
    """Mayúsculas/minúsculas/acentos/espacios inconsistentes."""
    if not s:
        return s
    r = rng.random()
    if r < 0.05:
        return s.upper()
    if r < 0.09:
        return s.lower()
    if r < 0.12:
        return I.strip_accents(s)
    if r < 0.135:
        return s + " "
    return s


def balance(monto, r, n, k):
    if r == 0:
        return monto * (1 - k / float(n))
    a = (1 + r) ** n
    return monto * (a - (1 + r) ** k) / (a - 1)


def ts_db2(d, rng):
    return "%04d-%02d-%02d-%02d.%02d.%02d.000000" % (
        d.year, d.month, d.day, rng.randint(6, 20), rng.randint(0, 59), rng.randint(0, 59))


# ---------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="/data")
    ap.add_argument("--workers", type=int, default=int(os.environ.get("SCALE_WORKERS", 250000)))
    ap.add_argument("--patrones", type=int, default=int(os.environ.get("SCALE_PATRONES", 15000)))
    ap.add_argument("--bimestres", type=int, default=int(os.environ.get("BIMESTRES", 12)))
    ap.add_argument("--pago-meses", type=int, default=int(os.environ.get("PAGO_MESES", 24)))
    ap.add_argument("--seed", type=int, default=int(os.environ.get("SEED", 20261102)))
    ap.add_argument("--as-of", default=os.environ.get("AS_OF", ""), help="YYYY-MM-DD (default: hoy)")
    a = ap.parse_args()

    t_ini = time.time()
    rng = random.Random(a.seed)
    as_of = date.fromisoformat(a.as_of) if a.as_of else date.today()
    W, P = a.workers, a.patrones
    periods = build_periods(as_of, a.bimestres)
    N = len(periods)
    ends = [p["end"] for p in periods]
    ventana_ini = periods[0]["start"]

    os.makedirs(os.path.join(a.out, "db2"), exist_ok=True)
    os.makedirs(os.path.join(a.out, "hana"), exist_ok=True)
    o = {}
    for name in DB2_TABLES:
        o["db2." + name] = Out(os.path.join(a.out, "db2", name + ".csv"))
    for name in HANA_TABLES:
        o["hana." + name] = Out(os.path.join(a.out, "hana", name + ".csv"))

    print("== INAVIT datagen | seed=%d as_of=%s workers=%d patrones=%d bimestres=%d (%s..%s)" % (
        a.seed, as_of, W, P, N, periods[0]["label"], periods[-1]["label"]), flush=True)

    # --- catálogos de HANA ---------------------------------------------------
    for e in C.ENTIDADES:
        o["hana.CAT_ENTIDAD"].row([e[0], e[1], e[3]])
    for pr in C.PRODUCTOS:
        o["hana.CAT_PRODUCTO_CREDITO"].row([pr[0], pr[1], pr[2], money(pr[3]), money(pr[4]), money(pr[7] * 1.2)])

    # --- distribuciones precalculadas -------------------------------------
    ENT_CW = C.cum_weights([e[4] for e in C.ENTIDADES])
    NH_CW = C.cum_weights(C.zipf_weights(len(C.NOMBRES_H), 0.7, 4))
    NM_CW = C.cum_weights(C.zipf_weights(len(C.NOMBRES_M), 0.7, 4))
    AP_CW = C.cum_weights(C.zipf_weights(len(C.APELLIDOS), 0.9, 3))
    SEC_CW = C.cum_weights([s[1] for s in C.SECTORES])
    FORMA_CW = C.cum_weights([f[1] for f in C.FORMAS])
    PROD_CW = C.cum_weights([p[8] for p in C.PRODUCTOS])
    CANAL_CW = C.cum_weights(C.CANALES_PESOS)
    GEST_TIPOS = ["LLAMADA", "SMS", "CARTA", "VISITA", "CONVENIO"]
    GEST_CW = C.cum_weights([0.45, 0.20, 0.18, 0.12, 0.05])
    GEST_RES = ["PROMESA_DE_PAGO", "NO_LOCALIZADO", "SIN_RESPUESTA", "PAGO_PARCIAL"]
    GEST_RES_CW = C.cum_weights([0.35, 0.25, 0.30, 0.10])

    # --- patrones ---------------------------------------------------------
    used_rp = set()
    p_rp, p_ent, p_start, p_stop, p_w = [], [], [], [], []
    p_rows = []
    n_omisos = 0
    for _ in range(P):
        rp = I.registro_patronal(rng, used_rp)
        ent_i = min(bisect.bisect_left(ENT_CW, rng.random() * ENT_CW[-1]), len(C.ENTIDADES) - 1)
        ent = C.ENTIDADES[ent_i]
        sec_row = wpick(rng, C.SECTORES, SEC_CW)
        sector, prefijos = sec_row[0], sec_row[2]
        forma = wpick(rng, C.FORMAS, FORMA_CW)[0]
        razon = "%s %s %s" % (rng.choice(prefijos), rng.choice(C.NUCLEOS), forma)
        # fecha de alta / inicio dentro de la ventana
        if rng.random() < 0.08 and N > 4:
            pstart = rng.randint(1, N - 3)
            per = periods[pstart]
            alta = per["start"] + timedelta(days=rng.randint(0, per["days"] - 1))
        else:
            pstart = 0
            alta = date(1990, 1, 1) + timedelta(days=rng.randint(0, (ventana_ini - date(1990, 1, 1)).days - 60))
        # omisión: deja de aportar a partir del bimestre 'stop'
        stop, fecha_baja, estatus = N, None, "A"
        if rng.random() < 0.07 and pstart <= N - 4:
            stop = rng.randint(pstart + 2, N - 1)
            n_omisos += 1
            r = rng.random()
            if r < 0.55:
                estatus = "S"
            elif r < 0.90:
                estatus = "A"          # omiso oculto: sigue "activo" en el padrón
            else:
                estatus, fecha_baja = "B", periods[stop - 1]["end"]
        rfc = I.rfc_moral(razon, alta, rng)
        r = rng.random()
        razon_out = razon.lower() if r < 0.03 else (razon.replace(" ", "  ", 1) if r < 0.05 else (razon + " " if r < 0.06 else razon))
        mun = rng.choice(ent[8])
        cp = "%02d%03d" % (ent[7], rng.randint(0, 999))
        p_rp.append(rp)
        p_ent.append(ent_i)
        p_start.append(pstart)
        p_stop.append(stop)
        p_w.append(rng.lognormvariate(0, 1.25))
        # TAMANIO (índice 4) se completa al contar trabajadores
        p_rows.append([rp, rfc, razon_out, sector, None, ent[0], mun, cp, alta.isoformat(),
                       fecha_baja.isoformat() if fecha_baja else None, estatus])
    P_CW = C.cum_weights(p_w)
    p_count = [0] * P

    def patron_nuevo_empleo():
        while True:
            q = min(bisect.bisect_left(P_CW, rng.random() * P_CW[-1]), P - 1)
            if p_stop[q] >= N and p_start[q] == 0:
                return q

    # --- trabajadores / aportaciones / créditos --------------------------------
    assign = rng.choices(range(P), cum_weights=P_CW, k=W)
    used_nss = set()
    apo_id = 0
    cred_id = 1300000000
    pago_id = 0
    gest_id = 0
    dups = []
    stats = {"trabajadores_activos": 0, "trabajadores_baja": 0, "con_credito": 0, "precalificados": 0,
             "creditos_por_estatus": {}, "creditos_morosos": 0,
             "creditos_por_grupo": {"sin_aportar": 0, "patron_omiso_reubicado": 0, "sin_incidencia": 0},
             "morosos_por_grupo": {"sin_aportar": 0, "patron_omiso_reubicado": 0, "sin_incidencia": 0}}
    w_trab, w_sub, w_apo = o["db2.TRABAJADOR"], o["db2.SUBCUENTA_VIVIENDA"], o["db2.APORTACION"]
    h_cred, h_pago, h_cob = o["hana.CREDITO"], o["hana.PAGO"], o["hana.COBRANZA"]
    prod_by_id = {p[0]: p for p in C.PRODUCTOS}

    for i in range(W):
        if i and i % 50000 == 0:
            print("   trabajadores: %d / %d (%.0fs)" % (i, W, time.time() - t_ini), flush=True)
        p = assign[i]
        ent_i = p_ent[p] if rng.random() < 0.92 else min(bisect.bisect_left(ENT_CW, rng.random() * ENT_CW[-1]), 31)
        ent = C.ENTIDADES[ent_i]
        sexo = "H" if rng.random() < 0.57 else "M"
        nombre = wpick(rng, C.NOMBRES_H, NH_CW) if sexo == "H" else wpick(rng, C.NOMBRES_M, NM_CW)
        ap_p = wpick(rng, C.APELLIDOS, AP_CW)
        ap_m = None if rng.random() < 0.02 else wpick(rng, C.APELLIDOS, AP_CW)
        edad = rng.triangular(21, 62, 36)
        nac = as_of - timedelta(days=int(edad * 365.25) + rng.randint(0, 364))
        alta = nac + timedelta(days=rng.randint(18 * 365, 28 * 365))
        if alta > as_of - timedelta(days=60):
            alta = as_of - timedelta(days=rng.randint(60, 900))
        nac_ent = ent if rng.random() < 0.7 else C.ENTIDADES[min(bisect.bisect_left(ENT_CW, rng.random() * ENT_CW[-1]), 31)]
        while True:
            nss = I.nss(rng.randint(1, 99), alta.year, nac.year, rng.randint(0, 9999))
            if nss not in used_nss:
                used_nss.add(nss)
                break
        curp = I.curp(nombre, ap_p, ap_m, nac, sexo, nac_ent[2], rng)
        rfc = I.rfc_fisica(curp[:4], nac, rng)

        # ventana de aportaciones --------------------------------------------
        if rng.random() < 0.08 and N > 3:
            wstart = rng.randint(1, N - 2)
        else:
            wstart = bisect.bisect_left(ends, alta)
        if alta < ventana_ini:
            prior_bim = int(((ventana_ini - alta).days / 61.0) * rng.uniform(0.6, 0.95))
        else:
            prior_bim = 0

        sdi = rng.lognormvariate(math.log(430), 0.5) * ent[6]
        sdi = round(min(max(sdi, MIN_SDI), 4200.0), 2)

        # segmentos (patron, t_ini, t_fin_excl) ---------------------------------
        segs = []
        t0 = max(wstart, p_start[p])
        stop = p_stop[p]
        if stop < N:
            if t0 < stop:
                segs.append((p, t0, stop))
            if rng.random() < 0.45:
                q = patron_nuevo_empleo()
                ts = stop + rng.randint(1, 3)
                if ts < N:
                    segs.append((q, ts, N))
        elif rng.random() < 0.06 and N - t0 > 4:
            tc = rng.randint(t0 + 2, N - 2)
            q = patron_nuevo_empleo()
            segs.append((p, t0, tc))
            segs.append((q, min(tc + rng.randint(0, 1), N - 1), N))
        elif t0 < N:
            segs.append((p, t0, N))

        sum_win, n_win, last_pago = 0.0, 0, None
        for (q, s, e) in segs:
            rp_q = p_rp[q]
            for t in range(s, e):
                if rng.random() < 0.015:
                    continue                    # omisión parcial de ese bimestre
                per = periods[t]
                dias = per["days"]
                if t == s and s > 0:
                    dias = rng.randint(15, dias)
                sdi_t = round(sdi / (1.05 ** ((N - 1 - t) // 6)), 2)
                monto = round(sdi_t * dias * TASA_APORTACION, 2)
                r = rng.random()
                if r < 0.0004:
                    dias = rng.randint(70, 95)   # DQ: días fuera de rango
                elif r < 0.0009:
                    monto = 0.0                  # DQ: aportación en cero
                if rng.random() < 0.035:
                    pago = per["end"] + timedelta(days=rng.randint(30, 150))
                    origen = "E"
                    if pago > as_of:
                        continue
                else:
                    pago = per["end"] + timedelta(days=rng.randint(1, 17))
                    origen = "N"
                apo_id += 1
                w_apo.row([apo_id, nss, rp_q, per["label"], money(sdi_t), dias, money(monto),
                           pago.isoformat(), origen, ts_db2(pago, rng)])
                sum_win += monto
                n_win += 1
                if last_pago is None or pago > last_pago:
                    last_pago = pago

        activo = bool(segs) and segs[-1][2] == N
        rp_actual = p_rp[segs[-1][0]] if segs else p_rp[p]
        p_count[segs[-1][0] if segs else p] += 1

        # crédito ---------------------------------------------------------------
        pc = 0.45 if (edad >= 23 and prior_bim >= 10) else 0.03
        tiene_credito = rng.random() < pc

        avg_prior = sdi * 61 * TASA_APORTACION * 0.75
        saldo = (prior_bim * avg_prior + sum_win) * rng.uniform(1.0, 1.06)
        if tiene_credito:
            saldo *= 0.12
        bim_cot = prior_bim + n_win
        if activo:
            stats["trabajadores_activos"] += 1
        else:
            stats["trabajadores_baja"] += 1
        if (not tiene_credito) and activo and bim_cot >= PRECALIF_BIMESTRES and saldo >= PRECALIF_SALDO:
            stats["precalificados"] += 1

        # fila Db2: TRABAJADOR (con suciedad sembrada) -------------------------
        r = rng.random()
        curp_o = None if r < 0.02 else (curp[:17] if r < 0.024 else curp)
        rfc_o = None if rng.random() < 0.06 else rfc
        r = rng.random()
        nac_o = date(1900, 1, 1) if r < 0.005 else (as_of + timedelta(days=rng.randint(30, 3000)) if r < 0.007 else nac)
        n_o, p_o = ensucia_texto(nombre, rng), ensucia_texto(ap_p, rng)
        m_o = ensucia_texto(ap_m, rng) if ap_m else None
        w_trab.row([nss, curp_o, rfc_o, n_o, p_o, m_o, nac_o.isoformat(), sexo, ent[0], rp_actual,
                    money(sdi), alta.isoformat(), "A" if activo else "B"])
        w_sub.row([nss, money(saldo), bim_cot, last_pago.isoformat() if last_pago else None, as_of.isoformat()])
        if rng.random() < 0.005:
            dups.append((curp_o or curp, rfc_o, n_o, p_o, m_o, nac_o, sexo, ent[0], rp_actual, sdi, alta, nac))

        if not tiene_credito:
            continue

        # ===== crédito, pagos y cobranza (HANA) =====================================
        stats["con_credito"] += 1
        (pid, pname, ptipo, tmin, tmax, plazos, mmin, mmax, _pw, pmora) = prod_by_id[
            wpick(rng, C.PRODUCTOS, PROD_CW)[0]]
        plazo_m = rng.choice(plazos) * 12
        tasa = round(rng.uniform(tmin, tmax), 2)
        rm = tasa / 1200.0
        # El monto sale de la capacidad de pago: mensualidad objetivo = 15%-33% del ingreso mensual
        mens_objetivo = rng.uniform(0.15, 0.33) * sdi * 30.4
        monto = mens_objetivo * (1 - (1 + rm) ** (-plazo_m)) / rm
        monto = float(min(max(round(monto, -2), mmin * 0.4), mmax * 1.2))
        mens = monto * rm / (1 - (1 + rm) ** (-plazo_m))
        max_ago = min(84, int((edad - 21) * 12), plazo_m - 1)
        months_ago = max(1, min(int(rng.triangular(1, 84, 22)), max_ago))
        orig = add_months(as_of, -months_ago) - timedelta(days=rng.randint(0, 27))

        sin_empleo = not activo
        afectado = p_stop[p] < N            # su patrón original dejó de aportar
        liq_p = 0.20 if (ptipo == "MEJORAMIENTO" and months_ago >= plazo_m * 0.5) else 0.012
        pm = min(0.065 * ent[5] * pmora * (6.0 if sin_empleo else (2.0 if afectado else 1.0)), 0.6)
        x = rng.random()
        estado, M, gap, dias_mora, L = "VIGENTE", 0, 0, 0, None
        if x < liq_p:
            estado = "LIQUIDADO"
            L = max(1, months_ago - rng.randint(0, min(5, months_ago - 1)))
        elif x < liq_p + pm:
            if months_ago >= 4 and rng.random() < 0.10:
                M0, gap0 = rng.randint(2, min(8, months_ago)), rng.randint(1, 6)
                if months_ago >= M0 + gap0:
                    M, gap, estado = M0, gap0, "REESTRUCTURADO"
            else:
                M = min(1 + int(rng.expovariate(0.25)), 30, months_ago)
                dias_mora = (M - 1) * 30 + rng.randint(1, 30)
                estado = "CARTERA_VENCIDA" if dias_mora >= 180 else "MOROSO"
        i0, i1 = months_ago - gap - M + 1, months_ago - gap

        if estado == "LIQUIDADO":
            saldo_cred = 0.0
        else:
            saldo_cred = balance(monto, rm, plazo_m, months_ago - M)
            if M and gap == 0:
                saldo_cred *= 1 + 0.012 * M
        grupo = "sin_aportar" if sin_empleo else ("patron_omiso_reubicado" if afectado else "sin_incidencia")
        stats["creditos_por_grupo"][grupo] += 1
        if M and gap == 0:
            stats["creditos_morosos"] += 1
            stats["morosos_por_grupo"][grupo] += 1
        stats["creditos_por_estatus"][estado] = stats["creditos_por_estatus"].get(estado, 0) + 1

        # pagos
        ultimo_pago = None
        first_i = max(1, months_ago - a.pago_meses + 1)
        for k in range(first_i, months_ago + 1):
            if estado == "LIQUIDADO" and k > L:
                break
            due = add_months(orig, k)
            if M and i0 <= k <= i1:
                if rng.random() < 0.15:
                    m_p, tipo = mens * rng.uniform(0.3, 0.7), "PAGO_DIRECTO"
                else:
                    continue
            elif estado == "LIQUIDADO" and k == L:
                m_p, tipo = max(mens, balance(monto, rm, plazo_m, k - 1)), "PAGO_ANTICIPADO"
            elif rng.random() < 0.02:
                m_p, tipo = mens * rng.uniform(1.5, 6.0), "PAGO_ANTICIPADO"
            elif sin_empleo or rng.random() < 0.12:
                m_p, tipo = mens, "PAGO_DIRECTO"
            else:
                m_p, tipo = mens, "DESCUENTO_NOMINA"
            canal = "NOMINA" if tipo == "DESCUENTO_NOMINA" else wpick(rng, C.CANALES_PAGO, CANAL_CW)
            f_pago = min(as_of, due + timedelta(days=rng.randint(-6, 5)))
            pago_id += 1
            h_pago.row([pago_id, cred_id + 1, f_pago.isoformat(), "%d%02d" % (due.year, due.month),
                        money(m_p), tipo, canal])
            if ultimo_pago is None or f_pago > ultimo_pago:
                ultimo_pago = f_pago

        # cobranza
        if M:
            d0, d1 = add_months(orig, i0), add_months(orig, i1)
            ng = rng.randint(1, min(6, M + 1))
            span = max(1, (d1 - d0).days)
            fechas = sorted(min(as_of, d0 + timedelta(days=rng.randint(0, span))) for _ in range(ng))
            despacho = rng.choice(C.DESPACHOS)
            for j, fch in enumerate(fechas):
                tipo_g = wpick(rng, GEST_TIPOS, GEST_CW)
                if estado == "REESTRUCTURADO" and j == len(fechas) - 1:
                    tipo_g = "CONVENIO"
                if tipo_g == "CONVENIO":
                    res = "CONVENIO_FIRMADO" if (estado == "REESTRUCTURADO" or rng.random() < 0.7) else "CONVENIO_RECHAZADO"
                else:
                    res = wpick(rng, GEST_RES, GEST_RES_CW)
                gest_id += 1
                h_cob.row([gest_id, cred_id + 1, fch.isoformat(), tipo_g, res, despacho])

        # fila CREDITO con suciedad ------------------------------------------------
        cred_id += 1
        base = " ".join(("%s %s %s" % (ap_p, ap_m or "", nombre)).split())
        r = rng.random()
        if r < 0.80:
            nom_c = I.strip_accents(base).upper()
        elif r < 0.90:
            nom_c = base.upper()
        elif r < 0.95:
            nom_c = base.title()
        elif r < 0.98:
            nom_c = I.strip_accents(base).upper().replace(" ", "  ", 1)
        else:
            nom_c = ("%s %s, %s" % (ap_p, ap_m or "", nombre)).upper().replace("  ", " ")

        r = rng.random()
        if r < 0.03:
            curp_c = None
        elif r < 0.07:
            curp_c = curp.lower()
        elif r < 0.085:
            curp_c = " " * 18
        elif r < 0.09:
            k = rng.randint(0, 16)
            curp_c = curp[:k] + ("A" if curp[k] != "A" else "B") + curp[k + 1:]
        else:
            curp_c = curp
        r = rng.random()
        rfc_c = None if r < 0.08 else (rfc.lower() if r < 0.11 else rfc)
        r = rng.random()
        if r < 0.004:
            while True:
                nss_c = I.nss(rng.randint(1, 99), rng.randint(80, 99), rng.randint(60, 99), rng.randint(0, 9999))
                if nss_c not in used_nss:
                    break                                # huérfano: no existe en Db2
        elif r < 0.007:
            nss_c = " " + nss
        else:
            nss_c = nss
        ent_c = ent if rng.random() < 0.9 else C.ENTIDADES[min(bisect.bisect_left(ENT_CW, rng.random() * ENT_CW[-1]), 31)]
        mun_c = rng.choice(ent_c[8])
        if rng.random() < 0.05:
            mun_c = mun_c.upper()
        est_c = estado
        if estado == "VIGENTE" and rng.random() < 0.04:
            est_c = rng.choice(["Vigente", "vigente ", "VIGENTE ", "VIG"])
        h_cred.row([cred_id, nss_c, curp_c, rfc_c, nom_c, pid, ent_c[0], mun_c, rp_actual,
                    orig.isoformat(), money(monto), plazo_m, money(tasa), money(mens), money(saldo_cred),
                    est_c, dias_mora, ultimo_pago.isoformat() if ultimo_pago else None])

    # --- duplicados por CURP con distinto NSS (sin aportaciones) --------------------
    for (curp_d, rfc_d, n_d, p_d, m_d, nac_o, sexo, ent_cl, rp, sdi, alta, nac) in dups:
        while True:
            nss_d = I.nss(rng.randint(1, 99), (alta.year + 1) % 100, nac.year, rng.randint(0, 9999))
            if nss_d not in used_nss:
                used_nss.add(nss_d)
                break
        w_trab.row([nss_d, curp_d, rfc_d, ensucia_texto(n_d, rng), p_d, m_d, nac_o.isoformat(), sexo, ent_cl,
                    rp, money(sdi), alta.isoformat(), "B"])
        w_sub.row([nss_d, money(0), 0, None, as_of.isoformat()])

    # --- PATRON (TAMANIO según trabajadores vigentes) ------------------------------
    for idx, row in enumerate(p_rows):
        c = p_count[idx]
        row[4] = "MICRO" if c <= 10 else ("PEQUENA" if c <= 50 else ("MEDIANA" if c <= 250 else "GRANDE"))
        o["db2.PATRON"].row(row)

    # --- cierre y manifiesto --------------------------------------------------------------
    counts = {}
    for k, w in o.items():
        w.close()
        counts[k] = w.n
    elapsed = time.time() - t_ini
    manifest = {
        "seed": a.seed, "as_of": as_of.isoformat(), "workers": W, "patrones": P,
        "bimestres": N, "periodo_inicial": periods[0]["label"], "periodo_final": periods[-1]["label"],
        "pago_meses": a.pago_meses, "filas": counts,
        "patrones_omisos": n_omisos, "kpis_demo": stats, "segundos": round(elapsed, 1),
    }
    with open(os.path.join(a.out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    with open(os.path.join(a.out, "manifest.env"), "w", encoding="utf-8") as f:
        f.write("MF_SEED=%d\nMF_AS_OF=%s\nMF_WORKERS=%d\nMF_PATRONES=%d\nMF_BIMESTRES=%d\nMF_PAGO_MESES=%d\n" % (
            a.seed, as_of.isoformat(), W, P, a.bimestres, a.pago_meses))
        for k, n in counts.items():
            f.write("ROWS_%s=%d\n" % (k.upper().replace(".", "_"), n))
    print("== Listo en %.0fs" % elapsed)
    for k, n in counts.items():
        print("   %-28s %12d" % (k, n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
