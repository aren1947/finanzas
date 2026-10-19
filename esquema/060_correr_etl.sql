-- El ETL vive en los archivos etl/*.sql del repo. `aren-supabase subir` copia cada archivo a _etl_pasos y correr_etl()
-- los ejecuta en orden de nombre, en la misma transacción que la escritura que lo disparó: si un paso falla, no se guarda nada.

create table if not exists _etl_pasos (
  archivo text primary key,        -- '023_plata_gastos.sql': el orden es el del nombre
  destino text not null,
  sql text not null,               -- un MERGE ... returning merge_action()
  actualizado timestamptz not null default now()
);

create or replace function correr_etl()
returns table (paso text, insertadas integer, actualizadas integer, borradas integer)
language plpgsql as $$
declare
  p record;
  fila record;
begin
  for p in select archivo, destino, sql from _etl_pasos order by archivo loop
    paso := p.destino; insertadas := 0; actualizadas := 0; borradas := 0;
    for fila in execute p.sql loop
      case fila.accion
        when 'INSERT' then insertadas := insertadas + 1;
        when 'UPDATE' then actualizadas := actualizadas + 1;
        when 'DELETE' then borradas := borradas + 1;
      end case;
    end loop;
    return next;
  end loop;
end $$;
