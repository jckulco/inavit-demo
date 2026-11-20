-- =============================================================================
-- INAVIT · Db2 · Sistema transaccional de aportaciones patronales
-- Esquema INAVIT_APO. Todas las tablas tienen llave primaria (requisito de CDC).
-- El orden de columnas debe coincidir con datagen/tables.py (lo valida test_schema.py).
-- Se ejecuta ya conectado a la base (db2 connect to INAVITDB).
-- =============================================================================

CREATE SCHEMA INAVIT_APO;

CREATE TABLE INAVIT_APO.PATRON (
  REGISTRO_PATRONAL  CHAR(11)     NOT NULL,
  RFC                VARCHAR(13),
  RAZON_SOCIAL       VARCHAR(120) NOT NULL,
  SECTOR             VARCHAR(40),
  TAMANIO            VARCHAR(10),
  ENTIDAD_CLAVE      CHAR(2)      NOT NULL,
  MUNICIPIO          VARCHAR(60),
  CODIGO_POSTAL      CHAR(5),
  FECHA_ALTA         DATE         NOT NULL,
  FECHA_BAJA         DATE,
  ESTATUS            CHAR(1)      NOT NULL,
  CONSTRAINT PK_PATRON PRIMARY KEY (REGISTRO_PATRONAL)
);

CREATE TABLE INAVIT_APO.TRABAJADOR (
  NSS                       CHAR(11)     NOT NULL,
  CURP                      CHAR(18),
  RFC                       VARCHAR(13),
  NOMBRE                    VARCHAR(60)  NOT NULL,
  APELLIDO_PATERNO          VARCHAR(40)  NOT NULL,
  APELLIDO_MATERNO          VARCHAR(40),
  FECHA_NACIMIENTO          DATE,
  SEXO                      CHAR(1),
  ENTIDAD_CLAVE             CHAR(2),
  REGISTRO_PATRONAL         CHAR(11),
  SALARIO_DIARIO_INTEGRADO  DECIMAL(10,2),
  FECHA_ALTA                DATE,
  ESTATUS                   CHAR(1)      NOT NULL,
  CONSTRAINT PK_TRABAJADOR PRIMARY KEY (NSS)
);

CREATE TABLE INAVIT_APO.SUBCUENTA_VIVIENDA (
  NSS                       CHAR(11)      NOT NULL,
  SALDO_PESOS               DECIMAL(14,2) NOT NULL,
  BIMESTRES_COTIZADOS       INTEGER       NOT NULL,
  FECHA_ULTIMA_APORTACION   DATE,
  FECHA_CORTE               DATE          NOT NULL,
  CONSTRAINT PK_SUBCUENTA PRIMARY KEY (NSS)
);

CREATE TABLE INAVIT_APO.APORTACION (
  APORTACION_ID             BIGINT        NOT NULL,
  NSS                       CHAR(11)      NOT NULL,
  REGISTRO_PATRONAL         CHAR(11)      NOT NULL,
  PERIODO                   CHAR(6)       NOT NULL,   -- AAAABB (BB = bimestre 01..06)
  SALARIO_DIARIO_INTEGRADO  DECIMAL(10,2),
  DIAS_COTIZADOS            SMALLINT,
  MONTO_APORTACION          DECIMAL(12,2) NOT NULL,
  FECHA_PAGO                DATE,
  ORIGEN                    CHAR(1)       NOT NULL,   -- N normal | E extemporánea | D demo en vivo
  FECHA_REGISTRO            TIMESTAMP     NOT NULL DEFAULT CURRENT TIMESTAMP,
  CONSTRAINT PK_APORTACION PRIMARY KEY (APORTACION_ID)
);

-- Los IDs generados llegan hasta ~3 M; la demo en vivo usa esta secuencia (>= 100 M).
CREATE SEQUENCE INAVIT_APO.SEQ_APORTACION AS BIGINT
  START WITH 100000000 INCREMENT BY 1 NO CYCLE CACHE 20;

CREATE INDEX INAVIT_APO.IDX_APO_NSS     ON INAVIT_APO.APORTACION (NSS, PERIODO);
CREATE INDEX INAVIT_APO.IDX_APO_PATRON  ON INAVIT_APO.APORTACION (REGISTRO_PATRONAL, PERIODO);
CREATE INDEX INAVIT_APO.IDX_TRAB_PATRON ON INAVIT_APO.TRABAJADOR (REGISTRO_PATRONAL);
CREATE INDEX INAVIT_APO.IDX_TRAB_CURP   ON INAVIT_APO.TRABAJADOR (CURP);

COMMENT ON TABLE INAVIT_APO.PATRON             IS 'Patrones registrados. ESTATUS: A activo, S suspendido, B baja';
COMMENT ON TABLE INAVIT_APO.TRABAJADOR         IS 'Derechohabientes. ESTATUS: A con aportaciones vigentes, B sin aportaciones';
COMMENT ON TABLE INAVIT_APO.SUBCUENTA_VIVIENDA IS 'Saldo de la subcuenta de vivienda por trabajador';
COMMENT ON TABLE INAVIT_APO.APORTACION         IS 'Aportaciones patronales bimestrales (5% del salario diario integrado)';
