-- plata_dolar: Cotizaciones del dólar con su fecha, como número.
-- Lee: bronce_dolar. Clave: bronce_id.
merge into plata_dolar t
using (
  select id as bronce_id, fecha::date as fecha, num(valor) as valor
  from bronce_dolar
) s
on t.bronce_id = s.bronce_id
when matched and (t.fecha, t.valor) is distinct from (s.fecha, s.valor) then
  update set fecha = s.fecha, valor = s.valor
when not matched then
  insert (bronce_id, fecha, valor)
  values (s.bronce_id, s.fecha, s.valor)
when not matched by source then
  delete
returning merge_action() as accion;
