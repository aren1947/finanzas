-- plata_pagos_deuda: Pagos parciales de una deuda.
-- Lee: bronce_pagos_deuda. Clave: bronce_id.
merge into plata_pagos_deuda t
using (
  select id as bronce_id, deuda_id, fecha::date as fecha, monto
  from bronce_pagos_deuda
) s
on t.bronce_id = s.bronce_id
when matched and (t.deuda_id, t.fecha, t.monto) is distinct from (s.deuda_id, s.fecha, s.monto) then
  update set deuda_id = s.deuda_id, fecha = s.fecha, monto = s.monto
when not matched then
  insert (bronce_id, deuda_id, fecha, monto)
  values (s.bronce_id, s.deuda_id, s.fecha, s.monto)
when not matched by source then
  delete
returning merge_action() as accion;
