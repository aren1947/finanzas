-- plata_deudas: Deudas: las de bronce_deudas y la parte del otro de cada gasto compartido.
-- Lee: bronce_compartidos, bronce_deudas, dim_persona. Clave: origen, bronce_id.
merge into plata_deudas t
using (
  select 'bronce_deudas' as origen, b.id as bronce_id, b.fecha::date as fecha,
    (select id from dim_persona where nombre = b.persona) as persona_id,
    coalesce(b.concepto, 'Sin detalle') as concepto, num(b.monto) as monto, b.moneda,
    case b.sentido when 'debes' then 'le_debo' when 'te_deben' then 'me_deben' else b.sentido end as sentido
  from bronce_deudas b
  union all
  select 'bronce_compartidos', c.id, c.fecha::date, (select id from dim_persona where nombre = c.persona), c.descripcion,
    case when c.pago = 'yo' then c.total - c.mi_parte else c.mi_parte end, 'ARS',
    case when c.pago = 'yo' then 'me_deben' else 'le_debo' end
  from bronce_compartidos c
  where (case when c.pago = 'yo' then c.total - c.mi_parte else c.mi_parte end) > 0
) s
on t.origen = s.origen and t.bronce_id = s.bronce_id
when matched and (t.fecha, t.persona_id, t.concepto, t.monto, t.moneda, t.sentido) is distinct from (s.fecha, s.persona_id, s.concepto, s.monto, s.moneda, s.sentido) then
  update set fecha = s.fecha, persona_id = s.persona_id, concepto = s.concepto, monto = s.monto, moneda = s.moneda, sentido = s.sentido
when not matched then
  insert (origen, bronce_id, fecha, persona_id, concepto, monto, moneda, sentido)
  values (s.origen, s.bronce_id, s.fecha, s.persona_id, s.concepto, s.monto, s.moneda, s.sentido)
when not matched by source then
  delete
returning merge_action() as accion;
