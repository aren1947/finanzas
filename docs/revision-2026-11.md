# Revisión del repo `finanzas` — noviembre 2026

Revisión del código y del historial de git. **No se miró la base real** (había un conector de Supabase disponible y no se usó):
todo lo "comprobado" se comprobó en un Postgres 17.10 local con datos inventados, usando `tests/correr.sh`.

- **Comprobado**: lo reproduje en local; el caso queda en `tests/casos/`.
- **Comprobado (suelto)**: lo reproduje con una consulta suelta, sin dejar test.
- **Por lectura**: sale de leer el código; no lo ejecuté.
- **Sospecha**: depende de cómo llegan los datos reales o de cómo está configurado Supabase, y eso no lo pude ver.

Este informe no copia ningún valor sensible: dice dónde está cada cosa y de qué tipo es.

---

## Parte 1 — Exposición

Busqué en los archivos y en todo el historial (2 commits en `main`, sin otras ramas, tags ni PRs en GitHub; el historial
solo agrega líneas, no hay nada borrado que haya quedado en un commit viejo):
claves, tokens, JWT, URLs de Supabase u otras, mails, CBU/CVU/alias, DNI/CUIT, números de tarjeta, nombres de bancos y
comercios, montos y nombres de personas.

**No hay** claves, tokens, URLs del proyecto de Supabase, montos reales, cuentas bancarias ni números de tarjeta.
El repo cumple lo que dice: es solo código.

| # | Dónde | Tipo de dato | Gravedad | Qué hacer |
|---|---|---|---|---|
| E1 | Metadatos de los 2 commits (autor y committer) | Mail personal del dueño | Baja | Es normal en GitHub, pero para los commits que vengan se puede configurar el mail `noreply` de GitHub. Para borrarlo de los commits viejos hay que reescribir el historial, y eso lo decide Tomás |
| E2 | Usuario de los commits; `README.md`; comentarios de `esquema/` | Nombre y apellido del dueño (en el usuario) y nombre de pila; nombre del asistente | Baja | Informativo. Junto con el repo público, ata los datos de la base a una persona identificable |
| E3 | Comentario de cabecera de `etl/012_dim_etiqueta.sql` (commit `3b15b3b`) | Nombre de pila de un tercero, dado como ejemplo de etiqueta | Baja | **Lo saqué en este PR** (lo cambié por un ejemplo genérico). Sigue en el historial |
| E4 | `README.md` (sección "Cómo se usa") | Ruta del server y nombre de la herramienta interna | Muy baja | Informativo |
| E5 | Todo el esquema, `esquema/070_acceso.sql` | No es un dato: describe qué se registra (sueldo bruto y retención, deudas con personas) y el modelo de acceso (clave pública + login de Google) | — | Le da contexto a quien quiera aprovechar H1 y H2, y por eso esos dos van primero |

---

## Parte 2 — Correctitud

Ordenado por gravedad. El número de cada caso de test coincide con `tests/fallas_conocidas.txt`.

### Alta

#### H1. Volver a subir una vista le saca `security_invoker` y la deja legible para cualquier login de Google — **comprobado** · arreglado en este PR
`070_acceso.sql` pone `security_invoker = true` con `alter view`. Pero todas las vistas se crean con `create or replace view`
**sin** esa opción, y en Postgres `create or replace view` *reemplaza* las opciones de la vista. Así que cada vez que se sube un archivo de
`vistas/` (`aren-supabase subir … vistas`) sin volver a correr `070`, la vista corre como su dueño (`postgres`, que no pasa por
RLS). `authenticated` tiene `select` sobre las vistas por los permisos por defecto de Supabase (070 solo se los saca a `anon`),
y `authenticated` es **cualquier cuenta de Google que se loguee**, esté o no en `_cuentas_habilitadas`.
El README avisa que hay que volver a correr 070 al *crear* una vista; al *editar* una, no.

- Caso: `101_rls_vista_recreada` (antes del arreglo, un login no habilitado veía los movimientos).
- Arreglo: cada `create or replace view` de `vistas/` ahora dice `with (security_invoker = true)`. No cambia ningún resultado.
- **Para Tomás, hoy mismo**: no sé cómo está la base real. Esta consulta (solo lectura) lista las vistas que quedaron sin la opción:
  ```sql
  select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'v'
    and not coalesce('security_invoker=true' = any(c.reloptions), false);
  ```
  Si devuelve algo, volvé a correr `070_acceso.sql`.

#### H2. Una tabla o vista nueva queda abierta a cualquier login hasta volver a correr 070 — **comprobado (suelto)**
Por los permisos por defecto de Supabase, toda tabla nueva en `public` le da todos los permisos a `authenticated`, y sin RLS.
Creé una tabla de prueba después de 070: un login no habilitado la leía entera. Es el mismo riesgo que H1, pero con tablas.
Recomendaciones, sin PR porque tocan la configuración de Supabase:
- En Supabase Auth, **apagar el alta de usuarios nuevos** (*Allow new users to sign up*) y crear a mano las cuentas que entran.
  Así `authenticated` deja de ser "cualquiera con Google", y H1 y H2 pasan a ser un problema menor.
- Sacarle a `authenticated` los permisos por defecto en `public` (`alter default privileges … revoke all on tables from authenticated`)
  y dárselos tabla por tabla en 070. O agregar un *event trigger* que active RLS en cada tabla nueva.

#### H4. Si un resumen tiene dos compras con la misma descripción, no se puede registrar su pago — **comprobado**
`oro_resumen_items` es único por `(plata_pago_id, descripcion)`, y la descripción es `nombre · detalle`. Con dos gastos con tarjeta
llamados igual en el mismo resumen (por ejemplo, dos "Uber"), o dos líneas del mismo comercio el mismo día, `registrar_pago` falla
con *duplicate key* y el pago no se guarda.
- Caso: `200_resumen_descripcion_repetida`.
- Arreglo propuesto (no lo hice porque cambia una restricción de oro): que la clave del ítem sea un identificador de la fila de origen
  (por ejemplo, `origen` + id de la línea, del compromiso o del fijo), no el texto.

#### H6. La misma compra con tarjeta, cargada a mano y después llegada en el PDF, cuenta doble — **comprobado**
`oro_resumenes_detalle` suma las líneas del PDF **y** los gastos con tarjeta cargados a mano (`oro_compromisos_tarjeta`), sin
emparejarlos. A los fijos con tarjeta los corta con `periodo > último vencimiento cargado`; a los manuales, no. Al pagar, la foto del
resumen guarda las dos y `oro_movimientos` cuenta el gasto dos veces. En el caso: pagué 1000 y figuran 2000 de gasto.
- Caso: `202_tarjeta_manual_y_pdf`.
- Arreglo propuesto: aplicarles a los compromisos manuales el mismo corte que a los fijos (solo meses sin PDF cargado), o emparejarlos por
  tarjeta, fecha y monto. Es una decisión de diseño, así que la dejo para Tomás.

#### H7. Montos con formato argentino y fechas día/mes se guardan mal sin avisar — **comprobado** · arreglado para lo que se cargue de ahora en más
- `num()` toma el número del principio con punto decimal: `'1.500'` queda **1,5**, `'1.234,56'` queda 1,234 y `'1500,50'` queda 1500.
- Las fechas de bronce se pasan a `date` con `::date`, que depende de `DateStyle`. En Supabase es `ISO, MDY`, así que `'02/11/2026'`
  queda **11 de febrero**. Si el día es mayor que 12, falla. Si no, se guarda mal.
- Casos: `204_monto_formato_argentino`, `205_fecha_dia_mes`, `211_entradas_validas`.
- Arreglo: `procedimientos/000_validar_entrada.sql` (`valida_fecha`, `valida_mes`, `valida_monto`), que llaman `registrar_gasto`,
  `registrar_pago`, `registrar_dolar`, `registrar_fijo`, `registrar_deuda`, `registrar_compartido`, `saldar_deuda`, `pagar_deuda` y
  `compensar_deuda`. Aceptan `AAAA-MM-DD` y montos como `1500`, `1500.5`, `1500.50` o `-200`, que es lo que muestra el README. **Ojo:** rechazan
  entradas que hoy pasan (justamente las ambiguas). Si Aren manda otro formato, va a ver el error.
- No toca lo que ya está en bronce. Para revisar si quedó algo mal cargado (solo lectura):
  ```sql
  select 'gastos' t, id from bronce_gastos where monto !~ '^\s*-?[0-9]+(\.[0-9]{1,2})?\s*$' or fecha !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  union all select 'pagos', id from bronce_pagos where monto !~ '^\s*-?[0-9]+(\.[0-9]{1,2})?\s*$' or fecha !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  union all select 'deudas', id from bronce_deudas where monto !~ '^\s*-?[0-9]+(\.[0-9]{1,2})?\s*$' or fecha !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  union all select 'dolar', id from bronce_dolar where valor !~ '^\s*-?[0-9]+(\.[0-9]{1,2})?\s*$' or fecha !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  union all select 'servicios', id from bronce_servicios where monto !~ '^\s*-?[0-9]+(\.[0-9]{1,2})?\s*$';
  ```
  Las líneas de resumen y el sueldo usan otro formato a propósito (con coma decimal) y no entran en esta consulta.

### Media

#### H3. Desde la app se puede escribir directo en plata, oro y dimensiones — **comprobado**
La política de 070 es `for all` en **todas** las tablas. Una cuenta habilitada puede hacer `insert`/`update`/`delete` en `plata_*`,
`oro_*` y `dim_*` por la API, salteando bronce, y también borrar filas de bronce (que según el diseño solo se agrega). Casi todo lo
de plata y oro lo vuelve a armar el siguiente ETL, salvo `oro_resumen_items`: su MERGE se lee a sí mismo como fuente, así que
una fila escrita a mano ahí queda para siempre. Las dimensiones que no arma el ETL (categorías, medios, tarjetas, bancos) tampoco se reparan.
- Caso: `103_rls_escritura_directa`.
- Arreglo propuesto: solo `select` para `authenticated` en plata, oro y dim, y `correr_etl()` como `security definer` con `search_path`
  fijo (el SQL que ejecuta está en `_etl_pasos`, que la app no puede escribir). No lo hice porque, si se hace mal, la app deja de poder cargar.

#### H5. Un resumen no se puede pagar en dos partes — **comprobado**
`plata_pagos.clave` (`resumen|tarjeta|mes`) es única. El segundo pago del mismo resumen falla, ya sea un pago parcial o la parte en
dólares pagada aparte. Caso: `201_resumen_dos_pagos`.

#### H8. Un gasto con tarjeta con cuotas inválidas desaparecía — **comprobado** · arreglado
Con cuotas `'0'` o `'tres'`, `ent()` daba 0, `generate_series(1, 0)` no generaba ninguna cuota, y el gasto no aparecía en ningún lado
(los gastos con tarjeta no van a `oro_movimientos`). Además, sin `primer_mes`, todo el ETL fallaba con un error poco claro.
Ahora `registrar_gasto` exige cuotas enteras de 1 a 120 y `primer_mes` en formato `AAAA-MM`. Caso: `203_cuotas_invalidas`.

#### H9. Cuotas del resumen en formato corto (`1/3`) — **comprobado** · arreglado · **sospecha** sobre si pasa en los PDF reales
`021` cortaba la cuota con `substr(cuota, 1, 2)` y `substr(cuota, 4, 2)`. Con `'1/3'`, `cuota_total` quedaba 0 y la compra
desaparecía del detalle del resumen. Ahora usa `split_part(cuota, '/', n)`, que con `NN/NN` da exactamente lo mismo (lo comparé)
y además tolera espacios. Caso: `206_cuota_formato_corto`. Después de subir `etl/`, el ETL puede *recuperar* líneas que antes
se perdían.

#### H10. Cargar dos veces el mismo resumen duplica las compras — **comprobado**
`bronce_resumenes_lineas` no tiene control de duplicados. Caso: `207_pdf_cargado_dos_veces`. Las cuotas se salvan por el
`distinct` de `oro_cuotas_proyectadas`, pero eso trae H11. Propuesta: que el cargador rechace una línea con la misma tarjeta,
vencimiento, comprobante, fecha y monto que una ya cargada.

#### H11. Dos compras iguales en cuotas se juntan en una — **comprobado**
`oro_cuotas_proyectadas` hace `distinct` por tarjeta, referencia, cuotas, monto y mes inicial. Dos compras distintas con esos mismos
datos (por ejemplo, el mismo producto comprado dos veces) proyectan la mitad. Caso: `209_cuotas_iguales`. Convendría identificar la serie
por el comprobante.

#### H12. `oro_foto_mensual` resta dos veces lo ya pagado de la tarjeta — **comprobado**
`gastos_pagados` ya incluye las compras del resumen pagado (vienen de `oro_movimientos`), y `tarjetas_pendientes_resumen` vuelve a
restar todas las compras con vencimiento en ese mes, pagadas o no. Caso: `208_foto_mensual` (ingresé 100000, pagué 10000 y la foto
dice que quedan 80000 libres). Ninguna otra vista la usa; si la usa la app, el número está mal.

#### H13. Sueldo: retención con decimales y bruto con decimales — **comprobado** / **sospecha**
`'17,5%'` se lee como 17 y el neto queda mal (caso `210_sueldo_retencion_decimal`). Además, el bruto se limpia sacando *todos* los
puntos: si llegara con punto decimal (`1500000.50`), quedaría multiplicado por 100. No hay procedimiento para cargar el sueldo: lo carga
Aren directo en bronce, y no sé en qué formato.

#### H14. Fechas de resumen con año de 4 dígitos dan 2020 — **comprobado (suelto)** · **sospecha** sobre los PDF reales
`fecha_ddmmaa('15/10/2026')` da `2020-10-15`: hace `'20' || substr(t, 7, 2)`. Si algún resumen trae el año completo, todas sus fechas
quedan seis años atrás.

#### H15. No hay forma de dar de baja un fijo — **por lectura**
`024` pone `activa = 1` fijo, `plata_servicios.nombre` es único y no hay procedimiento para darlo de baja. Una suscripción cancelada se
sigue proyectando en `oro_compromisos_mes`, `tablero_proximos` y `tablero_ahorro`. Borrar su fila de bronce no sirve si ya tiene pagos
(rompe la FK de `plata_pagos`).

#### H16. Cuotas en dólares de los resúmenes se proyectan en cero; USD de resúmenes abiertos al dólar de hoy — **por lectura**
`oro_cuotas_proyectadas` solo lleva `monto_ars`, así que una compra en cuotas en dólares proyecta 0. Las líneas en USD sin cuotas se
valúan con `oro_dolar_vigente` (el último dólar cargado) hasta que se paga el resumen, y el detalle cambia cada vez que se carga una cotización.

### Baja

#### H17. Redondeo por cuota — **comprobado**
1000 en 3 cuotas: `tablero_pagos` y `tablero_tarjeta` redondean cada mes por separado y suman 999.99 (caso `301_cuotas_cierran`).
`oro_compromisos_tarjeta` guarda 333.333…, que suma bien. Si se quiere que cierre, la última cuota tiene que llevar la diferencia,
como hacen los bancos.

#### H18. Plata en `double precision` — **por lectura**
Todos los montos son `double precision`, y `num()` y `round()` trabajan sobre eso. Hoy se tapa redondeando al mostrar y con la tolerancia
de 0.005 en las deudas. En la prueba de compartidos con decimales (100.01 al 50%) todo cerró. Para plata conviene `numeric`, pero
migrar es un cambio grande y no es urgente.

#### H19. Los presupuestos y el tablero cuentan "gastado" distinto — **por lectura** · **sospecha** de doble conteo en el ahorro
- `tablero_presupuestos` suma `plata_gastos`: los gastos con tarjeta entran completos (todas las cuotas) en el mes de la compra, y las
  compras que solo llegaron por PDF no entran. `tablero_categorias` suma `oro_movimientos`, que sí las tiene. Para el mismo mes,
  el presupuesto y el tablero pueden dar números distintos.
- `tablero_ahorro`, desde el segundo mes proyectado, suma `tarjeta_mes` (el ritmo de gastos con tarjeta de los últimos 90 días) además de
  `comprometido`, que ya tiene las cuotas futuras de esos mismos gastos. Puede estar contando dos veces.

#### H20. Un presupuesto nuevo pisa los meses anteriores — **comprobado (suelto)**
`plata_presupuestos` se queda solo con el último límite de cada categoría y con su `desde`. Si cambiás el límite desde este mes,
los meses anteriores desaparecen de `tablero_presupuestos`, o pasan a mostrar el límite nuevo.

#### H21. Sin protección contra cargas repetidas — **sospecha**
Ningún procedimiento es idempotente. Si Aren reintenta una carga después de un timeout que en realidad sí se guardó, el gasto queda dos veces.
Se podría agregar un identificador de mensaje opcional, único en bronce.

#### H22. Detalles de dimensiones — **por lectura**
- `011`: un `dim_comercio` creado a mano, sin su fila en `bronce_nombres_compra`, lo borra el ETL junto con la categoría que se le
  haya puesto a mano.
- `010`: en `dim_persona` no se hace `trim`, pero en `dim_etiqueta` sí. Con un espacio de más ("Persona " y "Persona") quedan dos
  personas, y no se pueden compensar deudas entre ellas.
- `023`/`024`/`025`: `dim_tarjeta where nombre = x or nombre_visible = x` falla si dos tarjetas coinciden en esos campos cruzados.

#### H23. Otros menores — **por lectura**
- `tablero_resumen` y `tablero_series` arrancan en `'2026-01'` fijo.
- `029` y `compensar_deuda`: si no hay dólar a esa fecha, usan el último, aunque sea posterior.
- `pagar_deuda` acepta pagar más de lo que resta: la deuda queda en negativo y la cuenta muestra el pago entero.

### Lo que revisé y está bien

- RLS recién aplicado: `anon` no puede leer nada, un login no habilitado ve 0 filas, y el mail se compara sin importar mayúsculas (`100_rls_basico`).
- Un login no habilitado que llama a `correr_etl()` no ve las filas, así que el `when not matched by source then delete` no borra nada; y
  no puede cargar en bronce (`102_rls_etl_no_habilitado`).
- Gastos compartidos: mi parte es gasto, la del otro es deuda en el sentido correcto, la cuenta muestra el total pagado, pagar la
  deuda no suma gasto, y la mitad de 100.01 cierra (`300_compartido_cierra`).
- Gasto en USD: usa la cotización de la carga o la del día y, si no hay ninguna, falla en vez de guardar 0 (`302_usd`).
- Saldar dos veces falla entero, sin dejar nada a medias en bronce (`303_saldar_dos_veces`).
- Compensar una deuda en USD contra una en ARS con la misma persona convierte bien y no pasa de lo que resta (`304_compensar_usd_ars`).
- `correr_etl()` corre en la misma transacción que la carga: si un paso falla, no queda nada guardado.

---

## Qué trae este PR

| Cambio | Hallazgo | Para que llegue a la base |
|---|---|---|
| `with (security_invoker = true)` en todas las vistas | H1 | `aren-supabase subir … vistas` |
| `split_part` para las cuotas en `etl/021` | H9 | `aren-supabase subir … etl` |
| `procedimientos/000_validar_entrada.sql` y sus llamadas | H7, H8 | `aren-supabase subir … procedimientos` (subir `000` antes que el resto, o todo junto) |
| Comentario genérico en `etl/012` | E3 | — |
| `tests/` (runner, stub de Supabase, casos, fallas conocidas) | todos | nada: es solo local |

Ninguno de estos cambios es una migración ni toca tablas o datos.
