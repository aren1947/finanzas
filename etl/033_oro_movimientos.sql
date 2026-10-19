-- oro_movimientos: Hecho: cada movimiento de plata (sueldo, gastos de contado, pagos de fijos, resúmenes y sus compras, con las correcciones de Tomás).
-- Lee: bronce_correcciones_resumen, dim_categoria, dim_medio, dim_tarjeta, oro_resumen_items, plata_gastos, plata_pagos, plata_servicios, plata_sueldo. Clave: origen_tabla, origen_id.
merge into oro_movimientos t
using (
  select 'plata_sueldo' as origen_tabla, s.id as origen_id, s.fecha_cobro as fecha, 'ingreso' as tipo,
    (select id from dim_categoria where nombre = 'Sueldo') as categoria_id, null::integer as tarjeta_id,
    'Sueldo neto (bruto ' || trunc(s.bruto_ars)::bigint || ', retención ' || trunc(s.retencion_pct * 100)::bigint || '%)' as descripcion,
    s.neto_ars as monto_ars
  from plata_sueldo s
  union all
  select 'plata_gastos', g.id, g.fecha, 'gasto', g.categoria_id, null, g.descripcion, g.monto_ars
  from plata_gastos g join dim_medio md on md.id = g.medio_id
  where md.nombre <> 'tarjeta'
  union all
  select 'plata_pagos', p.id, p.fecha, 'gasto', s.categoria_id, null, s.nombre || ' · ' || p.mes, p.monto_ars
  from plata_pagos p join plata_servicios s on s.id = p.servicio_id
  where p.tipo = 'servicio'
  union all
  select 'plata_pagos', p.id, p.fecha, 'gasto', (select id from dim_categoria where nombre = 'Otros'), p.tarjeta_id,
    'Resumen ' || t.nombre_visible || ' sin detalle',
    p.monto_ars - coalesce((select sum(i.monto_ars) from oro_resumen_items i where i.plata_pago_id = p.id), 0)
  from plata_pagos p join dim_tarjeta t on t.id = p.tarjeta_id
  where p.tipo = 'resumen'
    and p.monto_ars - coalesce((select sum(i.monto_ars) from oro_resumen_items i where i.plata_pago_id = p.id), 0) > 0.005
  union all
  select 'oro_resumen_items', i.id,
    coalesce((select x.fecha::date from bronce_correcciones_resumen x where x.item_id = i.id and x.fecha is not null order by x.id desc limit 1), p.fecha),
    'gasto',
    coalesce((select c.id from dim_categoria c
              where c.nombre = (select x.categoria from bronce_correcciones_resumen x
                                where x.item_id = i.id and x.categoria is not null order by x.id desc limit 1)),
             i.categoria_id),
    i.tarjeta_id,
    coalesce((select x.descripcion from bronce_correcciones_resumen x where x.item_id = i.id and x.descripcion is not null order by x.id desc limit 1), i.descripcion),
    coalesce((select x.monto from bronce_correcciones_resumen x where x.item_id = i.id and x.monto is not null order by x.id desc limit 1), i.monto_ars)
  from oro_resumen_items i join plata_pagos p on p.id = i.plata_pago_id
) s
on t.origen_tabla = s.origen_tabla and t.origen_id = s.origen_id
when matched and (t.fecha, t.tipo, t.categoria_id, t.tarjeta_id, t.descripcion, t.monto_ars) is distinct from (s.fecha, s.tipo, s.categoria_id, s.tarjeta_id, s.descripcion, s.monto_ars) then
  update set fecha = s.fecha, tipo = s.tipo, categoria_id = s.categoria_id, tarjeta_id = s.tarjeta_id, descripcion = s.descripcion, monto_ars = s.monto_ars
when not matched then
  insert (origen_tabla, origen_id, fecha, tipo, categoria_id, tarjeta_id, descripcion, monto_ars)
  values (s.origen_tabla, s.origen_id, s.fecha, s.tipo, s.categoria_id, s.tarjeta_id, s.descripcion, s.monto_ars)
when not matched by source then
  delete
returning merge_action() as accion;
