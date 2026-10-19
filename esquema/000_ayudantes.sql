-- Ayudantes: fechas en hora de Argentina y números tolerantes, para que el resto del SQL se lea simple.
-- Los períodos son texto 'AAAA-MM' (como en la base anterior); las fechas de plata y oro son date.

create or replace function hoy() returns date language sql stable as $$
  select (now() at time zone 'America/Argentina/Buenos_Aires')::date
$$;

create or replace function mes_actual() returns text language sql stable as $$
  select to_char(hoy(), 'YYYY-MM')
$$;

-- mes_mas('2026-10', 3) = '2027-01'; acepta negativos
create or replace function mes_mas(periodo text, meses integer) returns text language sql immutable as $$
  select to_char(to_date(periodo || '-01', 'YYYY-MM-DD') + make_interval(months => meses), 'YYYY-MM')
$$;

-- meses de b a a: mes_diff('2026-12', '2026-10') = 2
create or replace function mes_diff(a text, b text) returns integer language sql immutable as $$
  select (substr(a, 1, 4)::int - substr(b, 1, 4)::int) * 12 + (substr(a, 6, 2)::int - substr(b, 6, 2)::int)
$$;

-- texto de bronce a número, como lo hacía SQLite: el número del principio, 0 si no hay, null si viene null
create or replace function num(t text) returns double precision language sql immutable as $$
  select case when t is null then null
              else coalesce(substring(trim(t) from '^[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?')::double precision, 0) end
$$;

-- lo mismo, entero (trunca, como SQLite)
create or replace function ent(t text) returns integer language sql immutable as $$
  select trunc(num(t))::integer
$$;

-- round(x, decimales) para double precision (Postgres solo lo trae para numeric)
create or replace function round(x double precision, decimales integer) returns double precision language sql immutable as $$
  select round(x::numeric, decimales)::double precision
$$;

-- fecha 'dd/mm/aa' de los resúmenes y recibos a date
create or replace function fecha_ddmmaa(t text) returns date language sql immutable as $$
  select to_date('20' || substr(t, 7, 2) || '-' || substr(t, 4, 2) || '-' || substr(t, 1, 2), 'YYYY-MM-DD')
$$;

-- el período 'AAAA-MM' de una fecha
create or replace function mes(d date) returns text language sql immutable as $$
  select to_char(d, 'YYYY-MM')
$$;

-- el mayor de dos valores, null si alguno es null (como MAX(a, b) de SQLite; greatest ignora los null)
create or replace function smax(a double precision, b double precision) returns double precision language sql immutable as $$
  select case when a is null or b is null then null else greatest(a, b) end
$$;
