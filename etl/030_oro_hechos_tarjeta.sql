-- oro_hechos_tarjeta: Hecho: cada línea de resumen con su tarjeta y la categoría de su comercio.
-- Lee: dim_categoria, dim_comercio, dim_tarjeta, plata_lineas_tarjeta. Clave: plata_id.
merge into oro_hechos_tarjeta t
using (
  select p.id as plata_id,
    (select id from dim_tarjeta where nombre = p.tarjeta) as tarjeta_id,
    coalesce((select c.categoria_id from dim_comercio c where c.referencia = p.referencia and c.cuotas_totales = coalesce(p.cuota_total, 0)),
             (select id from dim_categoria where nombre = 'Otros')) as categoria_id,
    p.fecha, p.vencimiento, p.tipo, p.referencia as descripcion, p.cuota_nro, p.cuota_total, p.monto_ars, p.monto_usd
  from plata_lineas_tarjeta p
) s
on t.plata_id = s.plata_id
when matched and (t.tarjeta_id, t.categoria_id, t.fecha, t.vencimiento, t.tipo, t.descripcion, t.cuota_nro, t.cuota_total, t.monto_ars, t.monto_usd) is distinct from (s.tarjeta_id, s.categoria_id, s.fecha, s.vencimiento, s.tipo, s.descripcion, s.cuota_nro, s.cuota_total, s.monto_ars, s.monto_usd) then
  update set tarjeta_id = s.tarjeta_id, categoria_id = s.categoria_id, fecha = s.fecha, vencimiento = s.vencimiento, tipo = s.tipo, descripcion = s.descripcion, cuota_nro = s.cuota_nro, cuota_total = s.cuota_total, monto_ars = s.monto_ars, monto_usd = s.monto_usd
when not matched then
  insert (plata_id, tarjeta_id, categoria_id, fecha, vencimiento, tipo, descripcion, cuota_nro, cuota_total, monto_ars, monto_usd)
  values (s.plata_id, s.tarjeta_id, s.categoria_id, s.fecha, s.vencimiento, s.tipo, s.descripcion, s.cuota_nro, s.cuota_total, s.monto_ars, s.monto_usd)
when not matched by source then
  delete
returning merge_action() as accion;
