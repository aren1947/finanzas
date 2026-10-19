-- Deudas y préstamos: sentido le_debo (Tomás debe) o me_deben (le deben a Tomás).

create or replace function registrar_deuda(p_origen text, p_fecha text, p_persona text, p_concepto text, p_monto text,
  p_moneda text default 'ARS', p_sentido text default 'me_deben')
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_deudas (origen, fecha, persona, concepto, monto, moneda, sentido, texto_crudo)
  values (p_origen, p_fecha, p_persona, p_concepto, p_monto, p_moneda, p_sentido, p_concepto);
  return query select * from etl_resumen();
end $$;

-- la marca saldada (una sola vez por deuda; deuda_id de tablero_deudas)
create or replace function saldar_deuda(p_origen text, p_deuda_id text, p_fecha text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_saldos_deuda (origen, deuda_id, fecha, texto_crudo)
  values (p_origen, p_deuda_id, coalesce(p_fecha, hoy()::text), p_deuda_id);
  return query select * from etl_resumen();
end $$;

-- deja de figurar como pendiente sin cargar ingreso ni gasto (ya se devolvió y no se anotó)
create or replace function olvidar_deuda(p_origen text, p_deuda_id text)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_saldos_deuda (origen, deuda_id, fecha, texto_crudo) values (p_origen, p_deuda_id, hoy()::text, 'olvidada');
  return query select * from etl_resumen();
end $$;

-- una parte de una deuda: baja lo que resta; en 0 queda saldada
create or replace function pagar_deuda(p_origen text, p_deuda_id integer, p_monto double precision, p_fecha text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_pagos_deuda (origen, deuda_id, fecha, monto) values (p_origen, p_deuda_id, coalesce(p_fecha, hoy()::text), p_monto);
  perform correr_etl();
  return query select to_jsonb(t) from (
    select clave, persona, concepto, monto, resta, estado from tablero_deudas where clave = 'deuda:' || p_deuda_id) t;
end $$;

-- compensa dos deudas con la misma persona en sentidos opuestos, aunque una sea en pesos y otra en dólares.
-- Sin monto, todo lo que se pueda; nunca más de lo que resta de ninguna. Convierte con el dólar del día.
create or replace function compensar_deuda(p_origen text, p_deuda_id integer, p_contra_deuda_id integer,
  p_monto double precision default null, p_moneda text default null, p_fecha text default null)
returns setof jsonb language plpgsql as $$
declare
  a record; b record;
  v_fecha date := coalesce(p_fecha::date, hoy());
  v_mon text; v_tc double precision; ra double precision; rb double precision;
begin
  select moneda, resta into a from tablero_deudas where clave = 'deuda:' || p_deuda_id;
  select moneda, resta into b from tablero_deudas where clave = 'deuda:' || p_contra_deuda_id;
  v_mon := coalesce(p_moneda, a.moneda);
  v_tc := coalesce(dolar_a(v_fecha), dolar_ultimo());
  ra := case when a.moneda = v_mon then a.resta when v_mon = 'USD' then a.resta / v_tc else a.resta * v_tc end;
  rb := case when b.moneda = v_mon then b.resta when v_mon = 'USD' then b.resta / v_tc else b.resta * v_tc end;
  insert into bronce_compensaciones (origen, fecha, deuda_id, contra_deuda_id, monto, moneda)
  values (p_origen, v_fecha::text, p_deuda_id, p_contra_deuda_id, round(least(coalesce(p_monto, ra), ra, rb), 2), v_mon);
  perform correr_etl();
  return query select to_jsonb(t) from (
    select clave, persona, concepto, moneda, resta, resta_ars, estado from tablero_deudas
    where clave in ('deuda:' || p_deuda_id, 'deuda:' || p_contra_deuda_id)) t;
end $$;
