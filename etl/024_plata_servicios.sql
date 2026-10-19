-- plata_servicios: Fijos (suscripciones y servicios) con su categoría, medio y tarjeta.
-- Lee: bronce_servicios, dim_categoria, dim_medio, dim_tarjeta. Clave: bronce_id.
merge into plata_servicios t
using (
  select b.id as bronce_id, b.nombre, num(b.monto) as monto, b.moneda, coalesce(b.frecuencia, 'mensual') as frecuencia,
    ent(nullif(b.dia, '')) as dia,
    (select id from dim_categoria where nombre = coalesce(b.categoria, 'Otros')) as categoria_id,
    (select id from dim_medio where nombre = b.medio) as medio_id,
    (select id from dim_tarjeta where nombre = b.tarjeta or nombre_visible = b.tarjeta) as tarjeta_id,
    1 as activa
  from bronce_servicios b
) s
on t.bronce_id = s.bronce_id
when matched and (t.nombre, t.monto, t.moneda, t.frecuencia, t.dia, t.categoria_id, t.medio_id, t.tarjeta_id, t.activa) is distinct from (s.nombre, s.monto, s.moneda, s.frecuencia, s.dia, s.categoria_id, s.medio_id, s.tarjeta_id, s.activa) then
  update set nombre = s.nombre, monto = s.monto, moneda = s.moneda, frecuencia = s.frecuencia, dia = s.dia, categoria_id = s.categoria_id, medio_id = s.medio_id, tarjeta_id = s.tarjeta_id, activa = s.activa
when not matched then
  insert (bronce_id, nombre, monto, moneda, frecuencia, dia, categoria_id, medio_id, tarjeta_id, activa)
  values (s.bronce_id, s.nombre, s.monto, s.moneda, s.frecuencia, s.dia, s.categoria_id, s.medio_id, s.tarjeta_id, s.activa)
when not matched by source then
  delete
returning merge_action() as accion;
