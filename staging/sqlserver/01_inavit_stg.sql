-- =============================================================================
-- INAVIT · VM3 (Windows Server 2025) · SQL Server 2019 · base de staging INAVIT_STG
-- Destino de la replicación IIDR desde Db2 (INAVITDB.INAVIT_APO).
-- DDL equivalente al de Db2 (vm1-fuentes/sql/db2/01_schema.sql). IIDR también puede
-- crear las tablas al mapear; si las creas aquí, mapea a tablas existentes.
-- Texto en NVARCHAR para conservar acentos (la base de Db2 es UTF-8).
-- =============================================================================

IF DB_ID('INAVIT_STG') IS NULL CREATE DATABASE INAVIT_STG;
GO
USE INAVIT_STG;
GO
IF SCHEMA_ID('INAVIT_APO') IS NULL EXEC('CREATE SCHEMA INAVIT_APO');
GO

CREATE TABLE INAVIT_APO.PATRON (
  REGISTRO_PATRONAL  CHAR(11)      NOT NULL,
  RFC                VARCHAR(13),
  RAZON_SOCIAL       NVARCHAR(120) NOT NULL,
  SECTOR             NVARCHAR(40),
  TAMANIO            VARCHAR(10),
  ENTIDAD_CLAVE      CHAR(2)       NOT NULL,
  MUNICIPIO          NVARCHAR(60),
  CODIGO_POSTAL      CHAR(5),
  FECHA_ALTA         DATE          NOT NULL,
  FECHA_BAJA         DATE,
  ESTATUS            CHAR(1)       NOT NULL,
  CONSTRAINT PK_PATRON PRIMARY KEY (REGISTRO_PATRONAL)
);

CREATE TABLE INAVIT_APO.TRABAJADOR (
  NSS                       CHAR(11)      NOT NULL,
  CURP                      CHAR(18),
  RFC                       VARCHAR(13),
  NOMBRE                    NVARCHAR(60)  NOT NULL,
  APELLIDO_PATERNO          NVARCHAR(40)  NOT NULL,
  APELLIDO_MATERNO          NVARCHAR(40),
  FECHA_NACIMIENTO          DATE,
  SEXO                      CHAR(1),
  ENTIDAD_CLAVE             CHAR(2),
  REGISTRO_PATRONAL         CHAR(11),
  SALARIO_DIARIO_INTEGRADO  DECIMAL(10,2),
  FECHA_ALTA                DATE,
  ESTATUS                   CHAR(1)       NOT NULL,
  CONSTRAINT PK_TRABAJADOR PRIMARY KEY (NSS)
);

CREATE TABLE INAVIT_APO.SUBCUENTA_VIVIENDA (
  NSS                       CHAR(11)      NOT NULL,
  SALDO_PESOS               DECIMAL(14,2) NOT NULL,
  BIMESTRES_COTIZADOS       INT           NOT NULL,
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
  FECHA_REGISTRO            DATETIME2     NOT NULL,
  CONSTRAINT PK_APORTACION PRIMARY KEY (APORTACION_ID)
);
GO
