-- Presupuestos, previstos, metas de ahorro y ahorro mínimo.

-- límite mensual de una categoría de gasto (0 lo quita); desde = AAAA-MM, este mes si no se pasa. Devuelve cómo va este mes
create or replace function fijar_presupuesto(p_origen text, p_categoria text, p_monto double precision, p_desde text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_presupuestos (origen, categoria, monto, desde) values (p_origen, p_categoria, p_monto, coalesce(p_desde, mes_actual()));
  perform correr_etl();
  return query select to_jsonb(t) from (
    select categoria, limite, gastado, round(limite - gastado, 2) as quedan, ritmo from tablero_presupuestos
    where categoria = p_categoria and periodo = mes_actual()) t;
end $$;

-- un gasto pensado pero no seguro (no cuenta para Gastado ni presupuestos). Devuelve el previsto y lo comprometido de ese mes
create or replace function registrar_previsto(p_origen text, p_periodo text, p_descripcion text, p_monto double precision,
  p_categoria text default null)
returns setof jsonb language plpgsql as $$
declare v_id integer;
begin
  insert into bronce_previstos (origen, periodo, descripcion, monto, categoria) values (p_origen, p_periodo, p_descripcion, p_monto, p_categoria)
  returning id into v_id;
  perform correr_etl();
  return query select to_jsonb(t) from (
    select p.id, p.periodo, p.descripcion, p.monto, p.categoria, x.total_ars as ya_comprometido, x.previsto as previsto_del_mes
    from tablero_previstos p left join tablero_proximos x on x.periodo = p.periodo where p.id = v_id) t;
end $$;

create or replace function postergar_previsto(p_origen text, p_previsto_id integer, p_periodo text)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_previstos_cambios (origen, previsto_id, accion, periodo) values (p_origen, p_previsto_id, 'postergar', p_periodo);
  perform correr_etl();
  return query select to_jsonb(t) from (
    select id, periodo, descripcion, monto, postergado from tablero_previstos where id = p_previsto_id) t;
end $$;

create or replace function descartar_previsto(p_origen text, p_previsto_id integer)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_previstos_cambios (origen, previsto_id, accion) values (p_origen, p_previsto_id, 'descartar');
  perform correr_etl();
  return query select to_jsonb(t) from (select id, descripcion, estado from plata_previstos where id = p_previsto_id) t;
end $$;

-- el gasto real se carga aparte, con registrar_gasto
create or replace function confirmar_previsto(p_origen text, p_previsto_id integer)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_previstos_cambios (origen, previsto_id, accion) values (p_origen, p_previsto_id, 'confirmar');
  perform correr_etl();
  return query select to_jsonb(t) from (select id, descripcion, estado from plata_previstos where id = p_previsto_id) t;
end $$;

-- una meta de ahorro: lo que no se pasa queda como estaba en la meta activa con ese nombre; monto 0 la quita
create or replace function fijar_meta_ahorro(p_origen text, p_nombre text, p_monto double precision default null,
  p_moneda text default null, p_para text default null, p_ya_tengo double precision default null)
returns setof jsonb language plpgsql as $$
declare prev record;
begin
  select b.* into prev from bronce_ahorro_metas b
  where lower(b.nombre) = lower(p_nombre)
    and b.id = (select max(z.id) from bronce_ahorro_metas z where lower(z.nombre) = lower(p_nombre))
    and b.monto > 0;
  insert into bronce_ahorro_metas (origen, nombre, monto, moneda, para, ya_tengo)
  values (p_origen, coalesce(prev.nombre, p_nombre), coalesce(p_monto, prev.monto), coalesce(p_moneda, prev.moneda, 'ARS'),
          case when p_monto = 0 then null else coalesce(p_para, prev.para) end, coalesce(p_ya_tengo, prev.ya_tengo, 0));
  perform correr_etl();
  return query select to_jsonb(t) from tablero_ahorro_metas t where lower(t.nombre) = lower(p_nombre);
end $$;

-- ahorro mínimo por mes en pesos (monto 0 lo quita). Devuelve este mes y el que viene contra el mínimo
create or replace function fijar_ahorro_minimo(p_origen text, p_monto double precision, p_desde text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_ahorro_minimo (origen, monto, desde) values (p_origen, p_monto, coalesce(p_desde, mes_actual()));
  perform correr_etl();
  return query select to_jsonb(t) from (select periodo, estado, ingreso, sale, sobra, minimo from tablero_ahorro where k in (0, 1)) t;
end $$;
