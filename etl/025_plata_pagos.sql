-- plata_pagos: Pagos de resúmenes y de fijos, con su clave tipo|tarjeta o fijo|mes, y USD a pesos con el dólar del día.
-- Lee: bronce_pagos, dim_tarjeta, plata_servicios. Clave: bronce_id.
merge into plata_pagos t
using (
  select b.id as bronce_id,
    case when b.tipo = 'resumen'
         then 'resumen|' || (select id from dim_tarjeta where nombre = b.tarjeta or nombre_visible = b.tarjeta) || '|' || b.mes
         else 'servicio|' || (select id from plata_servicios where nombre = b.servicio) || '|' || b.mes end as clave,
    b.fecha::date as fecha, b.tipo, b.mes,
    (select id from dim_tarjeta where nombre = b.tarjeta or nombre_visible = b.tarjeta) as tarjeta_id,
    (select id from plata_servicios where nombre = b.servicio) as servicio_id,
    case when b.moneda = 'USD' then num(b.monto) * dolar_a(b.fecha::date) else num(b.monto) end as monto_ars,
    case when b.moneda = 'USD' then num(b.monto) else 0 end as monto_usd,
    b.moneda,
    case when b.moneda = 'USD' then dolar_a(b.fecha::date) end as tipo_cambio
  from bronce_pagos b
) s
on t.bronce_id = s.bronce_id
when matched and (t.clave, t.fecha, t.tipo, t.mes, t.tarjeta_id, t.servicio_id, t.monto_ars, t.monto_usd, t.moneda, t.tipo_cambio) is distinct from (s.clave, s.fecha, s.tipo, s.mes, s.tarjeta_id, s.servicio_id, s.monto_ars, s.monto_usd, s.moneda, s.tipo_cambio) then
  update set clave = s.clave, fecha = s.fecha, tipo = s.tipo, mes = s.mes, tarjeta_id = s.tarjeta_id, servicio_id = s.servicio_id, monto_ars = s.monto_ars, monto_usd = s.monto_usd, moneda = s.moneda, tipo_cambio = s.tipo_cambio
when not matched then
  insert (bronce_id, clave, fecha, tipo, mes, tarjeta_id, servicio_id, monto_ars, monto_usd, moneda, tipo_cambio)
  values (s.bronce_id, s.clave, s.fecha, s.tipo, s.mes, s.tarjeta_id, s.servicio_id, s.monto_ars, s.monto_usd, s.moneda, s.tipo_cambio)
when not matched by source then
  delete
returning merge_action() as accion;
