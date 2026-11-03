-- Validaciones de lo que llega a los procedimientos de carga, antes de escribir en bronce.
-- Cortan con un mensaje claro lo que hoy se guardaría mal sin avisar (ver docs/revision-2026-11.md, H7 y H8):
-- - num() lee '1.500' como 1,5 y '1.234,56' como 1,234;
-- - '02/11/2026'::date depende de DateStyle y en Supabase (MDY) da 11 de febrero;
-- - cuotas '0' o 'tres' dejan un gasto con tarjeta sin ninguna cuota.
-- Solo miran lo nuevo: no cambian nada de lo que ya está en bronce.

-- fecha AAAA-MM-DD (null pasa: el procedimiento pone hoy o la columna lo rechaza)
create or replace function valida_fecha(t text) returns void language plpgsql immutable as $$
declare ok boolean;
begin
  if t is null then return; end if;
  begin
    ok := t ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' and to_char(to_date(t, 'YYYY-MM-DD'), 'YYYY-MM-DD') = t;
  exception when others then ok := false;
  end;
  if not ok then
    raise exception 'fecha: usá AAAA-MM-DD (por ejemplo 2026-11-02)';
  end if;
end $$;

-- mes AAAA-MM
create or replace function valida_mes(t text) returns void language plpgsql immutable as $$
begin
  if t is not null and t !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'mes: usá AAAA-MM (por ejemplo 2026-11)';
  end if;
end $$;

-- monto con punto decimal y hasta dos decimales, sin separador de miles: 1500, 1500.5, 1500.50
create or replace function valida_monto(t text) returns void language plpgsql immutable as $$
begin
  if t is not null and t !~ '^\s*-?[0-9]+(\.[0-9]{1,2})?\s*$' then
    raise exception 'monto: un número sin separador de miles y con punto decimal (1500 o 1500.50)';
  end if;
end $$;

-- cuotas de un gasto con tarjeta: un entero de 1 a 120, y el mes de la primera cuota
create or replace function valida_cuotas_tarjeta(p_cuotas text, p_primer_mes text) returns void language plpgsql immutable as $$
begin
  if p_cuotas is not null and (p_cuotas !~ '^\s*[0-9]+\s*$' or trim(p_cuotas)::integer not between 1 and 120) then
    raise exception 'cuotas: un número entero de 1 a 120';
  end if;
  if p_primer_mes is null then
    raise exception 'primer_mes: con tarjeta hace falta el mes de la primera cuota (AAAA-MM)';
  end if;
  perform valida_mes(p_primer_mes);
end $$;
