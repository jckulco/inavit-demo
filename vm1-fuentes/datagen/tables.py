# -*- coding: utf-8 -*-
"""
Definición única del orden de columnas de cada tabla.

Los CSV se escriben SIN encabezado y en este orden, que debe coincidir con el
orden de columnas de los DDL en sql/db2 y sql/hana. El script
datagen/test_schema.py lo verifica automáticamente.

Tipos: str | int | dec | date | ts
"""

DB2_SCHEMA = "INAVIT_APO"
HANA_SCHEMA = "INAVIT_FIN"

DB2_TABLES = {
    "PATRON": [
        ("REGISTRO_PATRONAL", "str"), ("RFC", "str"), ("RAZON_SOCIAL", "str"), ("SECTOR", "str"),
        ("TAMANIO", "str"), ("ENTIDAD_CLAVE", "str"), ("MUNICIPIO", "str"), ("CODIGO_POSTAL", "str"),
        ("FECHA_ALTA", "date"), ("FECHA_BAJA", "date"), ("ESTATUS", "str"),
    ],
    "TRABAJADOR": [
        ("NSS", "str"), ("CURP", "str"), ("RFC", "str"), ("NOMBRE", "str"), ("APELLIDO_PATERNO", "str"),
        ("APELLIDO_MATERNO", "str"), ("FECHA_NACIMIENTO", "date"), ("SEXO", "str"), ("ENTIDAD_CLAVE", "str"),
        ("REGISTRO_PATRONAL", "str"), ("SALARIO_DIARIO_INTEGRADO", "dec"), ("FECHA_ALTA", "date"),
        ("ESTATUS", "str"),
    ],
    "SUBCUENTA_VIVIENDA": [
        ("NSS", "str"), ("SALDO_PESOS", "dec"), ("BIMESTRES_COTIZADOS", "int"),
        ("FECHA_ULTIMA_APORTACION", "date"), ("FECHA_CORTE", "date"),
    ],
    "APORTACION": [
        ("APORTACION_ID", "int"), ("NSS", "str"), ("REGISTRO_PATRONAL", "str"), ("PERIODO", "str"),
        ("SALARIO_DIARIO_INTEGRADO", "dec"), ("DIAS_COTIZADOS", "int"), ("MONTO_APORTACION", "dec"),
        ("FECHA_PAGO", "date"), ("ORIGEN", "str"), ("FECHA_REGISTRO", "ts"),
    ],
}

# Orden de carga en Db2
DB2_LOAD_ORDER = ["PATRON", "TRABAJADOR", "SUBCUENTA_VIVIENDA", "APORTACION"]

HANA_TABLES = {
    "CAT_ENTIDAD": [("CLAVE", "str"), ("NOMBRE", "str"), ("REGION", "str")],
    "CAT_PRODUCTO_CREDITO": [
        ("PRODUCTO_ID", "int"), ("NOMBRE", "str"), ("TIPO", "str"),
        ("TASA_MIN", "dec"), ("TASA_MAX", "dec"), ("MONTO_MAX", "dec"),
    ],
    "CREDITO": [
        ("NUM_CREDITO", "int"), ("NSS", "str"), ("CURP", "str"), ("RFC", "str"), ("NOMBRE_ACREDITADO", "str"),
        ("PRODUCTO_ID", "int"), ("ENTIDAD_CLAVE", "str"), ("MUNICIPIO", "str"), ("REGISTRO_PATRONAL", "str"),
        ("FECHA_ORIGINACION", "date"), ("MONTO_ORIGINAL", "dec"), ("PLAZO_MESES", "int"), ("TASA_ANUAL", "dec"),
        ("MENSUALIDAD", "dec"), ("SALDO_ACTUAL", "dec"), ("ESTATUS_CREDITO", "str"), ("DIAS_MORA", "int"),
        ("FECHA_ULTIMO_PAGO", "date"),
    ],
    "PAGO": [
        ("PAGO_ID", "int"), ("NUM_CREDITO", "int"), ("FECHA_PAGO", "date"), ("PERIODO", "str"),
        ("MONTO_PAGO", "dec"), ("TIPO_PAGO", "str"), ("CANAL", "str"),
    ],
    "COBRANZA": [
        ("GESTION_ID", "int"), ("NUM_CREDITO", "int"), ("FECHA_GESTION", "date"), ("TIPO_GESTION", "str"),
        ("RESULTADO", "str"), ("DESPACHO", "str"),
    ],
}
HANA_LOAD_ORDER = ["CAT_ENTIDAD", "CAT_PRODUCTO_CREDITO", "CREDITO", "PAGO", "COBRANZA"]
