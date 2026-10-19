-- plata_precios_fijo: Historia de precios de cada fijo: su primer precio y lo pagado cada mes (el pago le gana al primer precio).
-- Lee: bronce_pagos, bronce_servicios, plata_pagos, plata_servicios. Clave: servicio_id, desde.
merge into plata_precios_fijo t
using (
  with c as (
    select s.id as servicio_id, null::integer as bronce_id, num(b.monto) as monto, b.moneda, b.desde, b.cotizacion as tipo_cambio,
           0 as prio, b.id as orden
    from bronce_servicios b join plata_servicios s on s.bronce_id = b.id
    where b.desde is not null
    union all
    select p.servicio_id, p.bronce_id, num(bp.monto), bp.moneda, p.mes, null, 1, bp.id
    from plata_pagos p join bronce_pagos bp on bp.id = p.bronce_id
    where p.tipo = 'servicio')
  select servicio_id, bronce_id, monto, moneda, desde, tipo_cambio
  from c
  where not exists (select 1 from c c2 where c2.servicio_id = c.servicio_id and c2.desde = c.desde
                      and (c2.prio > c.prio or (c2.prio = c.prio and c2.orden > c.orden)))
) s
on t.servicio_id = s.servicio_id and t.desde = s.desde
when matched and (t.bronce_id, t.monto, t.moneda, t.tipo_cambio) is distinct from (s.bronce_id, s.monto, s.moneda, s.tipo_cambio) then
  update set bronce_id = s.bronce_id, monto = s.monto, moneda = s.moneda, tipo_cambio = s.tipo_cambio
when not matched then
  insert (servicio_id, desde, bronce_id, monto, moneda, tipo_cambio)
  values (s.servicio_id, s.desde, s.bronce_id, s.monto, s.moneda, s.tipo_cambio)
when not matched by source then
  delete
returning merge_action() as accion;
