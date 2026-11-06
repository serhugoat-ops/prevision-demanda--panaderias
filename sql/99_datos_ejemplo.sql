-- =====================================================================
-- 99_datos_ejemplo.sql
-- Datos SINTÉTICOS para probar el modelo. No son datos de ningún cliente.
--
-- Genera 8 semanas de ventas de una panadería ficticia con:
--   - un patrón semanal (más ventas en fin de semana, bajón el martes)
--   - una ligera tendencia al alza
--   - un festivo que se comporta como domingo
--   - un día cerrado sin registros (para comprobar el salto de x)
--   - registros de la web con el producto escrito por nombre
--
-- Uso: ejecutar después de 00-05 y luego
--   SELECT generar_produccion_recomendada();
--   SELECT * FROM produccion_recomendada ORDER BY producto_id, fecha;
-- =====================================================================

INSERT INTO productos (cliente_id, producto_id, nombre) VALUES
    ('demo', '1', 'Barra grande'),
    ('demo', '2', 'Croissant'),
    ('demo', '3', 'Ensaimada')
ON CONFLICT DO NOTHING;

INSERT INTO dias_festivos (fecha, nombre) VALUES
    ('2026-05-01', 'Día del Trabajo')
ON CONFLICT DO NOTHING;

-- Histórico: 1 de abril a 25 de mayo de 2026, excepto el 15 de abril (cerrado)
INSERT INTO ventas_historicas (cliente_id, fecha, producto_id, producido, merma)
SELECT 'demo',
       d::date,
       p.producto_id,
       round(v * 1.15)::int,                    -- se horneaba un 15 % de más
       round(v * 1.15)::int - round(v)::int     -- y eso acababa en merma
FROM generate_series('2026-04-01'::date, '2026-05-25'::date, interval '1 day') AS d
CROSS JOIN (VALUES ('1', 60.0), ('2', 30.0), ('3', 12.0)) AS p(producto_id, base)
CROSS JOIN LATERAL (
    SELECT p.base
         * (1 + 0.004 * (d::date - '2026-04-01'::date))          -- tendencia
         * CASE WHEN extract(isodow FROM d) = 7 OR d::date = '2026-05-01' THEN 1.6
                WHEN extract(isodow FROM d) = 6 THEN 1.3
                WHEN extract(isodow FROM d) = 2 THEN 0.8
                ELSE 1.0 END                                      -- estacionalidad
         AS v
) calc
WHERE d::date <> '2026-04-15';

-- Dos días registrados desde la web: fichaje de mañana y de tarde por
-- separado, uno de ellos con el producto escrito por nombre.
INSERT INTO registros_merma (cliente_id, fecha_operativa, producto_id, cantidad_producida, cantidad_merma, turno) VALUES
    ('demo', '2026-05-26', '1',            70, 0, 'manana'),
    ('demo', '2026-05-26', 'barra-grande',  0, 6, 'tarde'),
    ('demo', '2026-05-26', '2',            32, 0, 'manana'),
    ('demo', '2026-05-26', 'croissant',     0, 3, 'tarde'),
    ('demo', '2026-05-27', '1',            72, 0, 'manana'),
    ('demo', '2026-05-27', '1',             0, 5, 'tarde');

-- Un registro anulado: no debe contar
INSERT INTO registros_merma (cliente_id, fecha_operativa, producto_id, cantidad_producida, cantidad_merma, turno, estado) VALUES
    ('demo', '2026-05-27', '2', 999, 0, 'manana', 'anulado');
