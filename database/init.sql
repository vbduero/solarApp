-- ============================================================
-- Solar-Grow - Script de Inicialización de Base de Datos
-- ============================================================

-- Crear usuario y base de datos
CREATE USER solar_grow_user WITH PASSWORD 'solar_grow_pass';
CREATE DATABASE solar_grow_db OWNER solar_grow_user;
GRANT ALL PRIVILEGES ON DATABASE solar_grow_db TO solar_grow_user;

-- Conectar a la base de datos
\c solar_grow_db;

-- Otorgar permisos en el esquema público
GRANT ALL ON SCHEMA public TO solar_grow_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO solar_grow_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO solar_grow_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO solar_grow_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO solar_grow_user;
