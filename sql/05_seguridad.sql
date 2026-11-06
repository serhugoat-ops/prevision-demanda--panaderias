-- =====================================================================
-- 05_seguridad.sql
-- Row Level Security de las tablas del modelo.
--
-- Criterio: estas tablas solo las escribe el backend (importaciones,
-- n8n, la función programada), que usa la clave service_role y por
-- tanto no está sujeto a RLS. Con RLS activado y sin políticas para
-- anon/authenticated, la clave pública de la web no puede leerlas ni
-- modificarlas.
--
-- Si en el futuro la web necesita leer produccion_recomendada con el
-- usuario autenticado, se añade una política de solo lectura filtrada
-- por cliente (ejemplo abajo), nunca una política "USING (true)".
-- =====================================================================

ALTER TABLE ventas_historicas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE dias_festivos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE produccion_recomendada ENABLE ROW LEVEL SECURITY;

-- Ejemplo: cada panadería ve solo sus recomendaciones, suponiendo que el
-- token del usuario lleva su cliente_id en app_metadata.
--
-- CREATE POLICY lectura_propia ON produccion_recomendada
--     FOR SELECT TO authenticated
--     USING (cliente_id = auth.jwt() -> 'app_metadata' ->> 'cliente_id');
