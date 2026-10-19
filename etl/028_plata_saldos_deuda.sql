-- plata_saldos_deuda: Deudas saldadas u olvidadas.
-- Lee: bronce_saldos_deuda. Clave: bronce_id.
merge into plata_saldos_deuda t
using (
  select id as bronce_id, ent(deuda_id) as deuda_id, fecha::date as fecha
  from bronce_saldos_deuda
) s
on t.bronce_id = s.bronce_id
when matched and (t.deuda_id, t.fecha) is distinct from (s.deuda_id, s.fecha) then
  update set deuda_id = s.deuda_id, fecha = s.fecha
when not matched then
  insert (bronce_id, deuda_id, fecha)
  values (s.bronce_id, s.deuda_id, s.fecha)
when not matched by source then
  delete
returning merge_action() as accion;
