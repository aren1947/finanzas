-- plata_lineas_tarjeta: Líneas de resumen de tarjeta: fechas, montos como número, cuotas separadas; sin pagos de saldo, percepciones ni totales.
-- Lee: bronce_resumenes_lineas. Clave: bronce_id.
merge into plata_lineas_tarjeta t
using (
  select id as bronce_id,
    case when referencia like 'SU PAGO%' then 'pago' else 'compra' end as tipo,
    tarjeta,
    fecha_ddmmaa(fecha_texto) as fecha,
    fecha_ddmmaa(vencimiento) as vencimiento,
    referencia,
    case when cuota <> '' then ent(split_part(cuota, '/', 1)) end as cuota_nro,
    case when cuota <> '' then ent(split_part(cuota, '/', 2)) end as cuota_total,
    nullif(comprobante, '') as comprobante,
    num(replace(replace(pesos_texto, '.', ''), ',', '.')) as monto_ars,
    num(replace(replace(dolares_texto, '.', ''), ',', '.')) as monto_usd
  from bronce_resumenes_lineas
  where fecha_texto <> '' and referencia not like 'PERCEP%' and referencia not like 'TOTAL%' and referencia not like 'SALDO%'
) s
on t.bronce_id = s.bronce_id
when matched and (t.tipo, t.tarjeta, t.fecha, t.vencimiento, t.referencia, t.cuota_nro, t.cuota_total, t.comprobante, t.monto_ars, t.monto_usd) is distinct from (s.tipo, s.tarjeta, s.fecha, s.vencimiento, s.referencia, s.cuota_nro, s.cuota_total, s.comprobante, s.monto_ars, s.monto_usd) then
  update set tipo = s.tipo, tarjeta = s.tarjeta, fecha = s.fecha, vencimiento = s.vencimiento, referencia = s.referencia, cuota_nro = s.cuota_nro, cuota_total = s.cuota_total, comprobante = s.comprobante, monto_ars = s.monto_ars, monto_usd = s.monto_usd
when not matched then
  insert (bronce_id, tipo, tarjeta, fecha, vencimiento, referencia, cuota_nro, cuota_total, comprobante, monto_ars, monto_usd)
  values (s.bronce_id, s.tipo, s.tarjeta, s.fecha, s.vencimiento, s.referencia, s.cuota_nro, s.cuota_total, s.comprobante, s.monto_ars, s.monto_usd)
when not matched by source then
  delete
returning merge_action() as accion;
