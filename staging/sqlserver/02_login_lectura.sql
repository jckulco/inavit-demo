-- =============================================================================
-- Login de solo lectura para DataStage (en lugar de usar sa).
-- Cambia la contraseña antes de ejecutar y guárdala en tu gestor de contraseñas.
-- =============================================================================
CREATE LOGIN inavit_reader WITH PASSWORD = '<CambiaEstaContraseña!2026>';
GO
USE INAVIT_STG;
GO
CREATE USER inavit_reader FOR LOGIN inavit_reader;
ALTER ROLE db_datareader ADD MEMBER inavit_reader;
GO
