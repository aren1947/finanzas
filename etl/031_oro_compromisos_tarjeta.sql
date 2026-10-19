-- oro_compromisos_tarjeta: Hecho: una fila por cuota de cada gasto con tarjeta, desde el primer mes elegido.
-- Lee: bronce_gastos, plata_gastos. Clave: plata_gasto_id, cuota_nro.
merge into oro_compromisos_tarjeta t
using (
  select g.id as plata_gasto_id, g.tarjeta_id, g.categoria_id, g.descripcion, k.n as cuota_nro, g.cuotas as cuota_total,
    mes_mas(b.primer_mes, k.n - 1) as periodo,
    g.monto_ars / g.cuotas as monto_ars, g.monto_usd / g.cuotas as monto_usd
  from plata_gastos g
    join bronce_gastos b on g.origen = 'bronce_gastos' and b.id = g.bronce_id
    cross join lateral generate_series(1, least(g.cuotas, 120)) as k(n)
  where b.medio = 'tarjeta'
) s
on t.plata_gasto_id = s.plata_gasto_id and t.cuota_nro = s.cuota_nro
when matched and (t.tarjeta_id, t.categoria_id, t.descripcion, t.cuota_total, t.periodo, t.monto_ars, t.monto_usd) is distinct from (s.tarjeta_id, s.categoria_id, s.descripcion, s.cuota_total, s.periodo, s.monto_ars, s.monto_usd) then
  update set tarjeta_id = s.tarjeta_id, categoria_id = s.categoria_id, descripcion = s.descripcion, cuota_total = s.cuota_total, periodo = s.periodo, monto_ars = s.monto_ars, monto_usd = s.monto_usd
when not matched then
  insert (plata_gasto_id, cuota_nro, tarjeta_id, categoria_id, descripcion, cuota_total, periodo, monto_ars, monto_usd)
  values (s.plata_gasto_id, s.cuota_nro, s.tarjeta_id, s.categoria_id, s.descripcion, s.cuota_total, s.periodo, s.monto_ars, s.monto_usd)
when not matched by source then
  delete
returning merge_action() as accion;
