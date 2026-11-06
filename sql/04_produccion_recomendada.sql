-- =====================================================================
-- 04_produccion_recomendada.sql
-- Convierte la previsión en una orden de producción y la guarda.
-- =====================================================================

-- Redondea SIEMPRE hacia arriba (CEIL): no se pueden hornear 12,3 barras
-- y, en caso de duda, quedarse corto (rotura de stock, cliente que se va
-- sin pan) se consideró peor que una unidad de merma.
-- Hace UPSERT, así que se puede ejecutar varias veces al día sin duplicar
-- filas y sin borrar el histórico de recomendaciones pasadas.
-- Devuelve el número de filas escritas.
CREATE OR REPLACE FUNCTION generar_produccion_recomendada()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    filas integer;
BEGIN
    INSERT INTO produccion_recomendada (cliente_id, fecha, producto_id, cantidad_recomendada)
    SELECT pr.cliente_id,
           pr.fecha,
           pr.producto_id,
           ceil(pr.prevision_ventas)::int
    FROM prevision_7_dias pr
    JOIN productos p USING (cliente_id, producto_id)
    WHERE p.activo                         -- productos descatalogados no se recomiendan
      AND pr.prevision_ventas IS NOT NULL  -- sin datos suficientes para la recta
    ON CONFLICT (cliente_id, fecha, producto_id)
    DO UPDATE SET cantidad_recomendada = EXCLUDED.cantidad_recomendada,
                  generado_en          = now();

    GET DIAGNOSTICS filas = ROW_COUNT;
    RETURN filas;
END;
$$;

-- Ejecución automática cada día a las 04:00, antes de que el obrador
-- empiece a hornear. Requiere la extensión pg_cron (Supabase → Database →
-- Extensions). Descomentar para activarlo:
--
-- SELECT cron.schedule(
--     'produccion-recomendada-diaria',
--     '0 4 * * *',
--     $$SELECT generar_produccion_recomendada()$$
-- );
