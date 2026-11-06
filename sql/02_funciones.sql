-- =====================================================================
-- 02_funciones.sql
-- Funciones auxiliares.
-- =====================================================================

-- Clasifica una fecha en su "grupo de día" para la estacionalidad semanal.
-- Domingos y festivos van juntos; el resto, por día de la semana.
-- Se centraliza aquí para no repetir el mismo CASE en cada vista
-- (antes estaba copiado seis veces y cualquier cambio rompía algo).
CREATE OR REPLACE FUNCTION grupo_dia(d date)
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT CASE
        WHEN extract(isodow FROM d) = 7
          OR EXISTS (SELECT 1 FROM dias_festivos f WHERE f.fecha = d)
            THEN '7. Domingos y festivos'
        ELSE extract(isodow FROM d)::int || '. ' ||
             (ARRAY['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'])
                 [extract(isodow FROM d)::int]
    END;
$$;

-- Traduce el producto_id que llega de la web al ID real del catálogo.
-- La web guarda unas veces el ID ("12") y otras el nombre con guiones
-- ("barra-grande"); este fue el origen de la mayoría de errores de tipo
-- (text vs bigint) durante el desarrollo. Se compara siempre como texto
-- y normalizando mayúsculas y guiones, sin convertir nunca a número.
CREATE OR REPLACE FUNCTION normalizar_producto(p_cliente text, p_valor text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT p.producto_id
    FROM productos p
    WHERE p.cliente_id = p_cliente
      AND (p.producto_id = p_valor
           OR lower(replace(p.nombre, '-', ' ')) = lower(replace(p_valor, '-', ' ')))
    ORDER BY (p.producto_id = p_valor) DESC  -- si coincide el ID, gana al nombre
    LIMIT 1;
$$;
