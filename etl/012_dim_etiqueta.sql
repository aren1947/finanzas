-- dim_etiqueta: Etiquetas libres para subcategorizar gastos (una persona o un contexto: Agus, amigos…), de lo que Tomás puso al cargar un gasto o un compartido.
-- Lee: bronce_compartidos, bronce_gastos. Clave: nombre.
merge into dim_etiqueta t
using (
  select distinct trim(etiqueta) as nombre from bronce_gastos where etiqueta is not null and trim(etiqueta) <> ''
  union
  select distinct trim(persona) from bronce_compartidos where persona is not null and trim(persona) <> ''
) s
on t.nombre = s.nombre
when not matched then
  insert (nombre)
  values (s.nombre)
when not matched by source then
  delete
returning merge_action() as accion;
