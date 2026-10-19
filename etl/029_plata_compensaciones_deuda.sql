-- plata_compensaciones_deuda: Compensaciones entre dos deudas con la misma persona: una fila por deuda, con el monto en la moneda de esa deuda (convertido con el dólar del día).
-- Lee: bronce_compensaciones, plata_deudas. Clave: bronce_id, deuda_id.
merge into plata_compensaciones_deuda t
using (
  with c as (
    select b.id as bronce_id, d.id as deuda_id, b.fecha::date as fecha, b.monto, b.moneda, d.moneda as moneda_deuda,
      coalesce(dolar_a(b.fecha::date), dolar_ultimo()) as tc
    from bronce_compensaciones b join plata_deudas d on d.id in (b.deuda_id, b.contra_deuda_id))
  select bronce_id, deuda_id, fecha,
    round(case when moneda = moneda_deuda then monto when moneda_deuda = 'USD' then monto / tc else monto * tc end, 2) as monto,
    moneda_deuda as moneda,
    case when moneda <> moneda_deuda then tc end as tipo_cambio
  from c
) s
on t.bronce_id = s.bronce_id and t.deuda_id = s.deuda_id
when matched and (t.fecha, t.monto, t.moneda, t.tipo_cambio) is distinct from (s.fecha, s.monto, s.moneda, s.tipo_cambio) then
  update set fecha = s.fecha, monto = s.monto, moneda = s.moneda, tipo_cambio = s.tipo_cambio
when not matched then
  insert (bronce_id, deuda_id, fecha, monto, moneda, tipo_cambio)
  values (s.bronce_id, s.deuda_id, s.fecha, s.monto, s.moneda, s.tipo_cambio)
when not matched by source then
  delete
returning merge_action() as accion;
