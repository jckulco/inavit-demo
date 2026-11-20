# -*- coding: utf-8 -*-
"""
Identificadores mexicanos SINTÉTICOS con estructura realista.

 - CURP: 18 caracteres, con dígito verificador válido (algoritmo oficial).
 - NSS : 11 dígitos, con dígito verificador (algoritmo de Luhn modificado).
 - RFC : estructura plausible (siglas + fecha + homoclave aleatoria). La
         homoclave NO calcula el dígito verificador oficial.
 - Registro patronal: 1 letra + 10 dígitos (ficticio).

Son identificadores inventados: no corresponden a personas ni empresas reales.
"""
import string
import unicodedata

_ALFABETO_CURP = "0123456789ABCDEFGHIJKLMNÑOPQRSTUVWXYZ"
_VOCALES = "AEIOU"
_PARTICULAS_AP = {"DE", "DEL", "LA", "LAS", "LOS", "Y", "MC", "MAC", "VON", "VAN"}
_PREFIJOS_NOMBRE = {"JOSE", "MARIA", "MA", "J"}
_ALNUM = string.ascii_uppercase + string.digits


def strip_accents(s):
    """Quita acentos y diéresis (la Ñ queda como N)."""
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))


def _norm(s):
    return strip_accents(s.upper().replace("Ñ", "X")) if s else ""


def _palabra_apellido(ap):
    toks = _norm(ap).split()
    for t in toks:
        if t not in _PARTICULAS_AP:
            return t
    return toks[0] if toks else "X"


def _palabra_nombre(nombre):
    toks = _norm(nombre).split()
    if len(toks) > 1 and toks[0] in _PREFIJOS_NOMBRE:
        return toks[1]
    return toks[0] if toks else "X"


def _vocal_interna(w):
    for c in w[1:]:
        if c in _VOCALES:
            return c
    return "X"


def _consonante_interna(w):
    for c in w[1:]:
        if c.isalpha() and c not in _VOCALES:
            return c
    return "X"


def curp_dv(s17):
    total = sum(_ALFABETO_CURP.index(c) * (18 - i) for i, c in enumerate(s17))
    return (10 - total % 10) % 10


def curp_valida(curp):
    if not curp or len(curp) != 18:
        return False
    try:
        return curp_dv(curp[:17]) == int(curp[17])
    except (ValueError, IndexError):
        return False


def curp(nombre, ap_pat, ap_mat, nacimiento, sexo, codigo_entidad, rng):
    p = _palabra_apellido(ap_pat)
    m = _palabra_apellido(ap_mat) if ap_mat else "X"
    n = _palabra_nombre(nombre)
    s = p[0] + _vocal_interna(p) + (m[0] if ap_mat else "X") + n[0]
    s += "%02d%02d%02d" % (nacimiento.year % 100, nacimiento.month, nacimiento.day)
    s += sexo + codigo_entidad
    s += _consonante_interna(p) + (_consonante_interna(m) if ap_mat else "X") + _consonante_interna(n)
    s += rng.choice(string.digits) if nacimiento.year < 2000 else rng.choice(string.ascii_uppercase)
    return s + str(curp_dv(s))


def nss_dv(d10):
    total = 0
    for i, ch in enumerate(d10):
        v = int(ch) * (1 if i % 2 == 0 else 2)
        total += v if v < 10 else v - 9
    return (10 - total % 10) % 10


def nss_valido(nss):
    return bool(nss) and len(nss) == 11 and nss.isdigit() and nss_dv(nss[:10]) == int(nss[10])


def nss(subdelegacion, anio_alta, anio_nac, serial):
    d = "%02d%02d%02d%04d" % (subdelegacion, anio_alta % 100, anio_nac % 100, serial)
    return d + str(nss_dv(d))


def _homoclave(rng):
    return "".join(rng.choice(_ALNUM) for _ in range(3))


def rfc_fisica(curp4, nacimiento, rng):
    return curp4 + "%02d%02d%02d" % (nacimiento.year % 100, nacimiento.month, nacimiento.day) + _homoclave(rng)


def rfc_moral(razon_social, alta, rng):
    ignorar = {"DE", "DEL", "LA", "LAS", "LOS", "Y", "S", "A", "C", "V", "R", "L", "P", "I", "SA", "CV", "SAS", "SC"}
    toks = [t for t in _norm(razon_social).replace(".", " ").split() if t not in ignorar]
    letras = "".join(t[0] for t in toks)[:3].ljust(3, "X")
    return letras + "%02d%02d%02d" % (alta.year % 100, alta.month, alta.day) + _homoclave(rng)


def registro_patronal(rng, usados):
    while True:
        rp = rng.choice(string.ascii_uppercase) + "".join(rng.choice(string.digits) for _ in range(10))
        if rp not in usados:
            usados.add(rp)
            return rp
