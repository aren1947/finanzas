-- plata_sueldo: Sueldo: fecha, bruto, retención y neto.
-- Lee: bronce_sueldo. Clave: bronce_id.
merge into plata_sueldo t
using (
  select b.id as bronce_id,
    fecha_ddmmaa(b.fecha_cobro_texto) as fecha_cobro,
    num(replace(b.bruto_texto, '.', '')) as bruto_ars,
    num(replace(b.retencion_texto, '%', '')) / 100 as retencion_pct,
    num(replace(b.bruto_texto, '.', '')) * num(replace(b.retencion_texto, '%', '')) / 100 as retencion_ars,
    num(replace(b.bruto_texto, '.', '')) * (1 - num(replace(b.retencion_texto, '%', '')) / 100) as neto_ars
  from bronce_sueldo b
) s
on t.bronce_id = s.bronce_id
when matched and (t.fecha_cobro, t.bruto_ars, t.retencion_pct, t.retencion_ars, t.neto_ars) is distinct from (s.fecha_cobro, s.bruto_ars, s.retencion_pct, s.retencion_ars, s.neto_ars) then
  update set fecha_cobro = s.fecha_cobro, bruto_ars = s.bruto_ars, retencion_pct = s.retencion_pct, retencion_ars = s.retencion_ars, neto_ars = s.neto_ars
when not matched then
  insert (bronce_id, fecha_cobro, bruto_ars, retencion_pct, retencion_ars, neto_ars)
  values (s.bronce_id, s.fecha_cobro, s.bruto_ars, s.retencion_pct, s.retencion_ars, s.neto_ars)
when not matched by source then
  delete
returning merge_action() as accion;
