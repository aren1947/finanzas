-- dim_persona: Personas: las que aparecen en deudas y gastos compartidos de bronce.
-- Lee: bronce_compartidos, bronce_deudas. Clave: nombre.
merge into dim_persona t
using (
  select persona as nombre from bronce_deudas where persona is not null
  union
  select persona from bronce_compartidos
) s
on t.nombre = s.nombre
when not matched then
  insert (nombre)
  values (s.nombre)
when not matched by source then
  delete
returning merge_action() as accion;
