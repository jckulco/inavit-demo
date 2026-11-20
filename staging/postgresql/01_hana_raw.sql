-- =============================================================================
-- INAVIT · VM3 · PostgreSQL · base inavit_stg, esquema hana_raw
-- Copia "cruda" de SAP HANA INAVIT_FIN que escribe DataStage (sin transformar).
-- DDL equivalente al de HANA (vm1-fuentes/sql/hana/01_schema.sql). Si en DataStage
-- usas "crear tabla" en el conector de destino, los nombres pueden quedar en
-- minúsculas: ajusta este archivo a lo que tengas.
-- =============================================================================
-- CREATE DATABASE inavit_stg;   -- ejecutar conectado a la base postgres
CREATE SCHEMA IF NOT EXISTS hana_raw;

CREATE TABLE IF NOT EXISTS hana_raw.cat_entidad (
  clave   varchar(2)  PRIMARY KEY,
  nombre  varchar(40) NOT NULL,
  region  varchar(30)
);

CREATE TABLE IF NOT EXISTS hana_raw.cat_producto_credito (
  producto_id  integer       PRIMARY KEY,
  nombre       varchar(60)   NOT NULL,
  tipo         varchar(30),
  tasa_min     numeric(5,2),
  tasa_max     numeric(5,2),
  monto_max    numeric(14,2)
);

-- NSS/CURP/RFC tal como se capturaron en HANA: la limpieza la hace DataStage al cargar Netezza.
CREATE TABLE IF NOT EXISTS hana_raw.credito (
  num_credito        bigint        PRIMARY KEY,
  nss                varchar(15),
  curp               varchar(18),
  rfc                varchar(13),
  nombre_acreditado  varchar(150),
  producto_id        integer,
  entidad_clave      varchar(2),
  municipio          varchar(60),
  registro_patronal  varchar(11),
  fecha_originacion  date,
  monto_original     numeric(14,2),
  plazo_meses        integer,
  tasa_anual         numeric(5,2),
  mensualidad        numeric(12,2),
  saldo_actual       numeric(14,2),
  estatus_credito    varchar(20),
  dias_mora          integer,
  fecha_ultimo_pago  date
);

CREATE TABLE IF NOT EXISTS hana_raw.pago (
  pago_id      bigint        PRIMARY KEY,
  num_credito  bigint        NOT NULL,
  fecha_pago   date          NOT NULL,
  periodo      varchar(6),
  monto_pago   numeric(12,2) NOT NULL,
  tipo_pago    varchar(20),
  canal        varchar(25)
);

CREATE TABLE IF NOT EXISTS hana_raw.cobranza (
  gestion_id     bigint      PRIMARY KEY,
  num_credito    bigint      NOT NULL,
  fecha_gestion  date        NOT NULL,
  tipo_gestion   varchar(20),
  resultado      varchar(25),
  despacho       varchar(40)
);
