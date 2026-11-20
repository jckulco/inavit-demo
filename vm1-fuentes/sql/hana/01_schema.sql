-- =============================================================================
-- INAVIT · SAP HANA Express · Módulo financiero (originación, cartera, cobranza)
-- Esquema INAVIT_FIN. El orden de columnas debe coincidir con datagen/tables.py.
-- Los errores del DROP inicial en una primera corrida son normales (se ignoran).
-- __APP_USER__ se reemplaza en tiempo de ejecución por HANA_APP_USER.
-- =============================================================================

DROP SCHEMA INAVIT_FIN CASCADE;
CREATE SCHEMA INAVIT_FIN;

CREATE COLUMN TABLE INAVIT_FIN.CAT_ENTIDAD (
  CLAVE   NVARCHAR(2)  NOT NULL PRIMARY KEY,
  NOMBRE  NVARCHAR(40) NOT NULL,
  REGION  NVARCHAR(30)
);

CREATE COLUMN TABLE INAVIT_FIN.CAT_PRODUCTO_CREDITO (
  PRODUCTO_ID  INTEGER       NOT NULL PRIMARY KEY,
  NOMBRE       NVARCHAR(60)  NOT NULL,
  TIPO         NVARCHAR(30),
  TASA_MIN     DECIMAL(5,2),
  TASA_MAX     DECIMAL(5,2),
  MONTO_MAX    DECIMAL(14,2)
);

-- NSS/CURP/RFC se guardan "tal como se capturaron" (pueden traer espacios o minúsculas).
CREATE COLUMN TABLE INAVIT_FIN.CREDITO (
  NUM_CREDITO        BIGINT        NOT NULL PRIMARY KEY,
  NSS                NVARCHAR(15),
  CURP               NVARCHAR(18),
  RFC                NVARCHAR(13),
  NOMBRE_ACREDITADO  NVARCHAR(150),
  PRODUCTO_ID        INTEGER,
  ENTIDAD_CLAVE      NVARCHAR(2),
  MUNICIPIO          NVARCHAR(60),
  REGISTRO_PATRONAL  NVARCHAR(11),
  FECHA_ORIGINACION  DATE,
  MONTO_ORIGINAL     DECIMAL(14,2),
  PLAZO_MESES        INTEGER,
  TASA_ANUAL         DECIMAL(5,2),
  MENSUALIDAD        DECIMAL(12,2),
  SALDO_ACTUAL       DECIMAL(14,2),
  ESTATUS_CREDITO    NVARCHAR(20),
  DIAS_MORA          INTEGER,
  FECHA_ULTIMO_PAGO  DATE
);

CREATE COLUMN TABLE INAVIT_FIN.PAGO (
  PAGO_ID      BIGINT        NOT NULL PRIMARY KEY,
  NUM_CREDITO  BIGINT        NOT NULL,
  FECHA_PAGO   DATE          NOT NULL,
  PERIODO      NVARCHAR(6),
  MONTO_PAGO   DECIMAL(12,2) NOT NULL,
  TIPO_PAGO    NVARCHAR(20),
  CANAL        NVARCHAR(25)
);

CREATE COLUMN TABLE INAVIT_FIN.COBRANZA (
  GESTION_ID     BIGINT       NOT NULL PRIMARY KEY,
  NUM_CREDITO    BIGINT       NOT NULL,
  FECHA_GESTION  DATE         NOT NULL,
  TIPO_GESTION   NVARCHAR(20),
  RESULTADO      NVARCHAR(25),
  DESPACHO       NVARCHAR(40)
);

GRANT SELECT ON SCHEMA INAVIT_FIN TO __APP_USER__;
