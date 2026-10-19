-- oro_resumen_items: Hecho: las compras de cada resumen pagado, como quedaron al pagarlo (foto: se agrega al pagar y no se recalcula).
-- Lee: dim_categoria, oro_movimientos, oro_resumenes_detalle, plata_pagos. Clave: plata_pago_id, descripcion.
merge into oro_resumen_items t
using (
  select plata_pago_id, tarjeta_id, periodo, categoria_id, descripcion, monto_ars
  from oro_resumen_items
  where plata_pago_id in (select id from plata_pagos)
  union all
  select p.id, d.tarjeta_id, d.periodo, c.id, d.nombre || ' · ' || d.detalle,
    case when d.moneda = 'USD' then d.monto * dolar_a(p.fecha) else d.monto end
  from plata_pagos p
    join oro_resumenes_detalle d on d.tarjeta_id = p.tarjeta_id and d.periodo = p.mes
    join dim_categoria c on c.nombre = d.categoria
  where p.tipo = 'resumen'
    and not exists (select 1 from oro_resumen_items i where i.plata_pago_id = p.id)
    and not exists (select 1 from oro_movimientos m where m.origen_tabla = 'plata_pagos' and m.origen_id = p.id)
) s
on t.plata_pago_id = s.plata_pago_id and t.descripcion = s.descripcion
when matched and (t.tarjeta_id, t.periodo, t.categoria_id, t.monto_ars) is distinct from (s.tarjeta_id, s.periodo, s.categoria_id, s.monto_ars) then
  update set tarjeta_id = s.tarjeta_id, periodo = s.periodo, categoria_id = s.categoria_id, monto_ars = s.monto_ars
when not matched then
  insert (plata_pago_id, descripcion, tarjeta_id, periodo, categoria_id, monto_ars)
  values (s.plata_pago_id, s.descripcion, s.tarjeta_id, s.periodo, s.categoria_id, s.monto_ars)
when not matched by source then
  delete
returning merge_action() as accion;
