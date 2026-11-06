-- =====================================================================
-- 03_vistas.sql
-- Cadena de cálculo del modelo de previsión.
--
--   ventas_diarias            demanda diaria por producto (histórico + web)
--        |
--   media_ventas_dia_semana   índice estacional de cada día de la semana
--        |
--   desestacionalizado        ventas sin el efecto "día de la semana"
--        |
--   prevision_7_dias          tendencia lineal + reestacionalización
--
-- Todas las vistas usan security_invoker para respetar el RLS de las
-- tablas (por defecto, una vista de Postgres se salta el RLS).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ventas_diarias
-- Une el histórico importado y los registros de la web, y agrupa por
-- cliente, día y producto. Los fichajes de mañana (producido) y de tarde
-- (merma) llegan en filas separadas y aquí se suman en una sola.
--   vendido = producido - merma  (lo que salió por caja ese día)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW ventas_diarias
WITH (security_invoker = true) AS
SELECT
    cliente_id,
    fecha,
    producto_id,
    sum(producido)::int               AS producido,
    sum(merma)::int                   AS merma,
    (sum(producido) - sum(merma))::int AS vendido
FROM (
    SELECT cliente_id, fecha, producto_id, producido, merma
    FROM ventas_historicas

    UNION ALL

    SELECT r.cliente_id,
           r.fecha_operativa,
           normalizar_producto(r.cliente_id, r.producto_id),
           r.cantidad_producida,
           r.cantidad_merma
    FROM registros_merma r
    WHERE r.estado = 'activo'           -- los registros anulados no cuentan
) todo
WHERE producto_id IS NOT NULL           -- productos que no están en el catálogo
GROUP BY cliente_id, fecha, producto_id;

-- ---------------------------------------------------------------------
-- 2. media_ventas_dia_semana
-- Índice estacional = media del grupo de día / media global del producto.
--   índice 1,25 en sábado -> los sábados se vende un 25 % más que un día medio
--   índice 0,80 en martes -> los martes se vende un 20 % menos
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW media_ventas_dia_semana
WITH (security_invoker = true) AS
WITH por_dia AS (
    SELECT cliente_id, producto_id, grupo_dia(fecha) AS dia_semana,
           avg(vendido) AS media_ventas_dia
    FROM ventas_diarias
    GROUP BY cliente_id, producto_id, grupo_dia(fecha)
),
global AS (
    SELECT cliente_id, producto_id, avg(vendido) AS media_global_producto
    FROM ventas_diarias
    GROUP BY cliente_id, producto_id
)
SELECT d.cliente_id,
       d.producto_id,
       d.dia_semana,
       d.media_ventas_dia,
       g.media_global_producto,
       d.media_ventas_dia / NULLIF(g.media_global_producto, 0) AS indice_estacional
FROM por_dia d
JOIN global g USING (cliente_id, producto_id);

-- ---------------------------------------------------------------------
-- 3. desestacionalizado
-- Divide cada venta por el índice de su día. Así un domingo de 35 barras
-- y un martes de 15 pueden valer lo mismo (p. ej. 20) y la serie muestra
-- la tendencia de fondo del negocio sin el "ruido" semanal.
-- Sin redondeos: la precisión completa se conserva para la regresión.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW desestacionalizado
WITH (security_invoker = true) AS
SELECT v.cliente_id,
       v.fecha,
       v.producto_id,
       v.vendido AS ventas_reales,
       m.dia_semana,
       m.indice_estacional,
       v.vendido / NULLIF(m.indice_estacional, 0) AS ventas_desestacionalizadas
FROM ventas_diarias v
JOIN media_ventas_dia_semana m
  ON m.cliente_id  = v.cliente_id
 AND m.producto_id = v.producto_id
 AND m.dia_semana  = grupo_dia(v.fecha);

-- ---------------------------------------------------------------------
-- 4. prevision_7_dias
-- a) Recta de tendencia y = a·x + b sobre la serie desestacionalizada
--    (regr_slope / regr_intercept de Postgres).
--    x = días naturales desde el primer registro. Si un día no hay datos
--    (cierre, festivo sin apertura) x "salta", y la recta respeta el paso
--    real del tiempo. (En Excel, un gráfico de líneas numera las filas
--    1, 2, 3... e ignora los huecos; ese era el motivo de que Excel y SQL
--    dieran previsiones distintas al principio.)
-- b) Se proyectan los 7 días siguientes al último día registrado de la
--    panadería (el mismo para todos sus productos, aunque algún producto
--    no tuviera ventas ese día).
-- c) Se multiplica la tendencia por el índice estacional del día futuro.
-- d) GREATEST(..., 0): una tendencia descendente nunca da ventas negativas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW prevision_7_dias
WITH (security_invoker = true) AS
WITH datos AS (
    SELECT cliente_id,
           producto_id,
           fecha,
           ventas_desestacionalizadas AS y,
           min(fecha) OVER (PARTITION BY cliente_id, producto_id) AS primera_fecha
    FROM desestacionalizado
    WHERE ventas_desestacionalizadas IS NOT NULL
),
recta AS (
    SELECT cliente_id,
           producto_id,
           min(primera_fecha)                                   AS primera_fecha,
           regr_slope(y, fecha - primera_fecha + 1)             AS pendiente,
           regr_intercept(y, fecha - primera_fecha + 1)         AS interseccion
    FROM datos
    GROUP BY cliente_id, producto_id
),
ultimo_dia AS (
    SELECT cliente_id, max(fecha) AS ultima_fecha
    FROM datos
    GROUP BY cliente_id
),
futuro AS (
    SELECT r.cliente_id,
           r.producto_id,
           u.ultima_fecha + s.paso AS fecha,
           r.pendiente * ((u.ultima_fecha + s.paso) - r.primera_fecha + 1) + r.interseccion AS tendencia
    FROM recta r
    JOIN ultimo_dia u USING (cliente_id)
    CROSS JOIN generate_series(1, 7) AS s(paso)
)
SELECT f.cliente_id,
       f.producto_id,
       f.fecha,
       grupo_dia(f.fecha) AS dia_semana,
       f.tendencia        AS tendencia_desestacionalizada,
       m.indice_estacional,
       GREATEST(f.tendencia * m.indice_estacional, 0) AS prevision_ventas
FROM futuro f
LEFT JOIN media_ventas_dia_semana m
  ON m.cliente_id  = f.cliente_id
 AND m.producto_id = f.producto_id
 AND m.dia_semana  = grupo_dia(f.fecha);
