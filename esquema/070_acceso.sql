-- Acceso desde apps (2026-10-19). Aren usa la API de administración (rol postgres, dueño de todo: no pasa por RLS).
-- Una app entra con la clave pública (anon) y un login de Google, y solo ve algo si su mail está en _cuentas_habilitadas:
-- - RLS en todas las tablas, con una política: lee y escribe un usuario logueado con mail habilitado. Sin login, nada.
-- - Las vistas corren con los permisos de quien consulta (security_invoker), así también pasan por RLS.
-- - Los procedimientos ya corren como quien los llama: por RPC, un usuario habilitado escribe en bronce y corre el ETL.
-- - _etl_pasos (el SQL del ETL) y _cuentas_habilitadas solo los cambia Aren.
-- Se puede volver a correr; después de crear una tabla o vista nueva, correrlo de nuevo (aren-supabase subir … esquema).
-- Una cuenta se habilita con: insert into _cuentas_habilitadas (mail, nombre) values ('alguien@gmail.com', 'Alguien').

create table if not exists _cuentas_habilitadas (
  mail text primary key check (mail = lower(mail)),
  nombre text,
  alta timestamptz not null default now()
);

-- el mail del login (Google lo da verificado; el registro con mail y contraseña está apagado en Supabase Auth)
create or replace function cuenta_habilitada() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from _cuentas_habilitadas where mail = lower(auth.jwt() ->> 'email'))
$$;
revoke execute on function cuenta_habilitada() from public, anon;
grant execute on function cuenta_habilitada() to authenticated;

do $$
declare t record;
begin
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r', 'p') loop
    execute format('alter table %I enable row level security', t.relname);
    execute format('drop policy if exists cuentas_habilitadas on %I', t.relname);
    if t.relname = '_etl_pasos' then
      execute format('create policy cuentas_habilitadas on %I for select to authenticated using (cuenta_habilitada())', t.relname);
    elsif t.relname <> '_cuentas_habilitadas' then
      execute format('create policy cuentas_habilitadas on %I for all to authenticated
                      using (cuenta_habilitada()) with check (cuenta_habilitada())', t.relname);
    end if;
  end loop;
  for t in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'v' loop
    execute format('alter view %I set (security_invoker = true)', t.relname);
  end loop;
end $$;

revoke insert, update, delete, truncate on _etl_pasos, _cuentas_habilitadas from anon, authenticated;
revoke select on _cuentas_habilitadas from anon, authenticated;

-- sin login no hay nada, ni siquiera qué tablas existen: la clave pública (anon) no tiene permisos en public
-- (por RLS vería 0 filas, pero tablero_resumen es un calendario y devolvería los meses en cero)
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated, service_role;
revoke execute on function cuenta_habilitada() from public, anon;
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon;
