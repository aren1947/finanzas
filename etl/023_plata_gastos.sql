-- plata_gastos: Gastos: los de bronce_gastos (USD a pesos con la cotización de la carga o la del día) y mi parte de cada gasto compartido. Un gasto de contado con más de una cuota falla (cuotas queda null).
-- Lee: bronce_compartidos, bronce_gastos, dim_categoria, dim_etiqueta, dim_medio, dim_tarjeta. Clave: origen, bronce_id.
merge into plata_gastos t
using (
  select 'bronce_gastos' as origen, b.id as bronce_id, b.fecha::date as fecha,
    case when b.moneda = 'USD' then num(b.monto) * coalesce(b.cotizacion, dolar_a(b.fecha::date)) else num(b.monto) end as monto_ars,
    case when b.moneda = 'USD' then num(b.monto) else 0 end as monto_usd,
    coalesce(b.moneda, 'ARS') as moneda,
    case when b.moneda = 'USD' then coalesce(b.cotizacion, dolar_a(b.fecha::date)) end as tipo_cambio,
    (select id from dim_categoria where nombre = coalesce(b.categoria, 'Otros')) as categoria_id,
    (select id from dim_medio where nombre = b.medio) as medio_id,
    case when b.medio = 'tarjeta' then (select id from dim_tarjeta where nombre = b.tarjeta or nombre_visible = b.tarjeta) end as tarjeta_id,
    case when b.medio = 'tarjeta' or coalesce(ent(nullif(b.cuotas, '')), 1) = 1 then coalesce(ent(nullif(b.cuotas, '')), 1) end as cuotas,
    b.descripcion,
    (select id from dim_etiqueta where nombre = trim(b.etiqueta)) as etiqueta_id
  from bronce_gastos b
  union all
  select 'bronce_compartidos', c.id, c.fecha::date, c.mi_parte, 0, 'ARS', null,
    (select id from dim_categoria where nombre = c.categoria),
    (select id from dim_medio where nombre = c.medio),
    null, 1,
    c.descripcion || ' (compartido con ' || c.persona || ')',
    (select id from dim_etiqueta where nombre = trim(c.persona))
  from bronce_compartidos c
  where c.mi_parte > 0
) s
on t.origen = s.origen and t.bronce_id = s.bronce_id
when matched and (t.fecha, t.monto_ars, t.monto_usd, t.moneda, t.tipo_cambio, t.categoria_id, t.medio_id, t.tarjeta_id, t.cuotas, t.descripcion, t.etiqueta_id) is distinct from (s.fecha, s.monto_ars, s.monto_usd, s.moneda, s.tipo_cambio, s.categoria_id, s.medio_id, s.tarjeta_id, s.cuotas, s.descripcion, s.etiqueta_id) then
  update set fecha = s.fecha, monto_ars = s.monto_ars, monto_usd = s.monto_usd, moneda = s.moneda, tipo_cambio = s.tipo_cambio, categoria_id = s.categoria_id, medio_id = s.medio_id, tarjeta_id = s.tarjeta_id, cuotas = s.cuotas, descripcion = s.descripcion, etiqueta_id = s.etiqueta_id
when not matched then
  insert (origen, bronce_id, fecha, monto_ars, monto_usd, moneda, tipo_cambio, categoria_id, medio_id, tarjeta_id, cuotas, descripcion, etiqueta_id)
  values (s.origen, s.bronce_id, s.fecha, s.monto_ars, s.monto_usd, s.moneda, s.tipo_cambio, s.categoria_id, s.medio_id, s.tarjeta_id, s.cuotas, s.descripcion, s.etiqueta_id)
when not matched by source then
  delete
returning merge_action() as accion;
