-- dim_comercio: Nombre y emoji legibles de cada compra de resumen (el último que dio Tomás). categoria_id se fija a mano y el ETL no la toca.
-- Lee: bronce_nombres_compra. Clave: referencia, cuotas_totales.
merge into dim_comercio t
using (
  select b.referencia, coalesce(ent(nullif(b.cuotas_totales, '')), 0) as cuotas_totales, b.nombre, b.emoji
  from bronce_nombres_compra b
  where b.id = (select max(x.id) from bronce_nombres_compra x
                where x.referencia = b.referencia
                  and coalesce(ent(nullif(x.cuotas_totales, '')), 0) = coalesce(ent(nullif(b.cuotas_totales, '')), 0))
) s
on t.referencia = s.referencia and t.cuotas_totales = s.cuotas_totales
when matched and (t.nombre, t.emoji) is distinct from (s.nombre, s.emoji) then
  update set nombre = s.nombre, emoji = s.emoji
when not matched then
  insert (referencia, cuotas_totales, nombre, emoji)
  values (s.referencia, s.cuotas_totales, s.nombre, s.emoji)
when not matched by source then
  delete
returning merge_action() as accion;
