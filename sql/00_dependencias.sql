-- =====================================================================
-- 00_dependencias.sql
-- Tablas de las que depende el modelo de previsión.
--
-- NO forman parte de mi trabajo: las diseñó Martí Rocamora como parte
-- de la aplicación web de captura de datos (formulario para panaderos +
-- flujos de n8n). Se incluyen en versión reducida, solo con las columnas
-- que usa el modelo, para que el repositorio se pueda ejecutar de punta
-- a punta en una base de datos vacía.
-- =====================================================================

-- Catálogo de productos de cada panadería
CREATE TABLE IF NOT EXISTS productos (
    cliente_id  text    NOT NULL,
    producto_id text    NOT NULL,
    nombre      text    NOT NULL,
    activo      boolean NOT NULL DEFAULT true,
    seccion     text,
    PRIMARY KEY (cliente_id, producto_id)
);

-- Registros que introducen los panaderos desde la web.
-- Cada fila es un fichaje: por la mañana se registra lo producido
-- (cantidad_merma = 0) y al cierre la merma (cantidad_producida = 0).
-- producto_id es texto: puede llegar como ID ("12") o, en registros
-- antiguos, como nombre ("barra-grande").
CREATE TABLE IF NOT EXISTS registros_merma (
    id_origen          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id         text        NOT NULL,
    timestamp_registro timestamptz NOT NULL DEFAULT now(),
    fecha_operativa    date        NOT NULL,
    producto_id        text        NOT NULL,
    cantidad_producida integer     NOT NULL DEFAULT 0,
    cantidad_merma     integer     NOT NULL DEFAULT 0,
    turno              text        NOT NULL DEFAULT 'manana',
    estado             text        NOT NULL DEFAULT 'activo'  -- 'activo' | 'anulado'
);
