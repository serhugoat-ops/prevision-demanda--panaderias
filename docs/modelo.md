# El modelo, paso a paso

Notación: `V(t)` son las ventas reales del día `t` de un producto, y `g(t)` es el grupo de día de `t` (lunes … sábado, o "domingo/festivo").

## 1. Ventas

```
V(t) = producido(t) − merma(t)
```

Esto mide lo que **salió por caja**, no la demanda real. Si un producto se agotó a mediodía, la demanda fue mayor que `V(t)` (demanda censurada). Es una limitación conocida: ver "Roturas de stock" más abajo.

## 2. Índice estacional

```
I(g) = media de V(t) en los días del grupo g
       ───────────────────────────────────────
       media de V(t) en todos los días
```

- `I = 1,44` en domingos y festivos: un domingo se vende un 44 % más que un día medio.
- `I = 0,74` en martes: un martes se vende un 26 % menos.

**Por qué agrupar los festivos con los domingos.** Un viernes festivo se parece más a un domingo (más bollería, picos a media mañana) que a un viernes normal. Si se dejara en "viernes", inflaría la media de los viernes y el modelo pediría hornear de más todos los viernes siguientes.

## 3. Desestacionalización

```
D(t) = V(t) / I(g(t))
```

Elimina el patrón semanal y deja la tendencia del negocio: si la panadería está ganando o perdiendo clientela.

## 4. Tendencia

Regresión lineal por mínimos cuadrados sobre `D(t)`:

```
D(x) ≈ a·x + b        x = días naturales desde el primer registro
```

**Por qué días naturales y no números de fila.** Si la tienda cierra un día, con números de fila el día siguiente quedaría "pegado" al anterior y la pendiente se calcularía sobre un tiempo comprimido. Con fechas, el hueco existe y la recta respeta el paso real del tiempo.

## 5. Previsión

```
P(t) = max( (a·x(t) + b) · I(g(t)), 0 )
```

Se calcula para los 7 días siguientes al último día con registros de la panadería.

## 6. Orden de producción

```
Q(t) = ⌈ P(t) ⌉
```

Siempre hacia arriba. Una unidad de merma cuesta menos que un cliente que se va sin pan y quizá no vuelve.

## Decisiones descartadas

| Alternativa | Por qué se descartó |
|---|---|
| Media móvil simple | Ignora la estructura semanal, que es la señal más fuerte del negocio |
| Stock de seguridad fijo | El producto caduca en 24 h: no se puede "guardar" el sobrante para mañana |
| Holt-Winters desde el principio | Con 3 o 4 semanas de datos, la primera semana atípica sesgaba todos los parámetros |
| Redondeo al entero más cercano | Producía roturas de stock en los productos estrella |

## Roturas de stock

El modelo optimiza sobre las ventas observadas. Para corregir la demanda censurada habría que registrar **a qué hora se agota** cada producto (la aplicación tiene una tabla `productos_agotados` pensada para ello) y estimar la demanda perdida en esas horas.

Estos cálculos son muy sencillos. El objetivo del proyecto era encontrar un cliente que facilitara 1 año de datos para aplicar estadística más compleja, pero al no conseguirse se detuvo aquí.
