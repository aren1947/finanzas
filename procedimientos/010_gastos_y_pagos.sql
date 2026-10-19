-- Procedimientos de carga: escriben solo en bronce y corren el ETL en la misma transacción.
-- Se llaman con nombres: select * from registrar_gasto(p_origen => 'mensaje', p_fecha => '2026-10-19', p_monto => '1000', ...).
-- Los parámetros son texto o número tal cual llegan; los que no se pasan quedan null. Devuelven filas jsonb:
-- lo que pide el procedimiento o, si no pide nada, lo que hizo el ETL en cada tabla.

create or replace function etl_resumen() returns setof jsonb language sql as $$
  select to_jsonb(e) from correr_etl() e where e.insertadas + e.actualizadas + e.borradas > 0
$$;

-- una categoría de en qué se gasta o de qué entra (tipo egreso o ingreso)
create or replace function crear_categoria(p_nombre text, p_emoji text default null, p_tipo text default 'egreso')
returns setof jsonb language plpgsql as $$
begin
  insert into dim_categoria (nombre, emoji, tipo) values (p_nombre, p_emoji, coalesce(p_tipo, 'egreso'));
  return query select to_jsonb(c) from dim_categoria c where c.nombre = p_nombre;
end $$;

-- un gasto: contado (medio debito, efectivo o transferencia) o tarjeta (tarjeta, cuotas, primer_mes AAAA-MM). Categoría vacía = Otros
create or replace function registrar_gasto(p_origen text, p_fecha text, p_monto text, p_moneda text default 'ARS',
  p_descripcion text default null, p_categoria text default null, p_forma text default 'contado', p_medio text default null,
  p_tarjeta text default null, p_cuotas text default null, p_primer_mes text default null, p_etiqueta text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_gastos (origen, fecha, monto, moneda, descripcion, categoria, medio, tarjeta, cuotas, primer_mes, texto_crudo, etiqueta)
  values (p_origen, p_fecha, p_monto, p_moneda, p_descripcion, coalesce(p_categoria, 'Otros'),
          case when p_forma = 'tarjeta' then 'tarjeta' else p_medio end, p_tarjeta, coalesce(p_cuotas, '1'),
          case when p_forma = 'tarjeta' then p_primer_mes end, p_descripcion, p_etiqueta);
  return query select * from etl_resumen();
end $$;

-- un gasto compartido: total, quién pagó (yo u otro) y mi parte (mi_monto, mi_porcentaje o la mitad)
create or replace function registrar_compartido(p_origen text, p_persona text, p_descripcion text, p_categoria text, p_total double precision,
  p_fecha text default null, p_pago text default 'yo', p_mi_monto double precision default null,
  p_mi_porcentaje double precision default null, p_medio text default null)
returns setof jsonb language plpgsql as $$
declare v_id integer;
begin
  insert into bronce_compartidos (origen, fecha, persona, descripcion, categoria, total, pago, mi_parte, medio)
  values (p_origen, coalesce(p_fecha, hoy()::text), p_persona, p_descripcion, p_categoria, p_total, coalesce(p_pago, 'yo'),
          round(coalesce(p_mi_monto, p_total * coalesce(p_mi_porcentaje, 50) / 100.0), 2),
          case when coalesce(p_pago, 'yo') = 'otro' then 'compartido' else coalesce(p_medio, 'debito') end)
  returning id into v_id;
  perform correr_etl();
  return query select to_jsonb(t) from (
    select fecha, persona, descripcion, total, mi_parte, pago, deuda_monto, sentido from tablero_compartidos where clave = 'comp:' || v_id) t;
end $$;

-- un fijo (suscripción o servicio): cobro = debito o el nombre de una tarjeta; desde = AAAA-MM del primer precio
create or replace function registrar_fijo(p_origen text, p_nombre text, p_monto text, p_moneda text default 'ARS',
  p_categoria text default null, p_cobro text default 'debito', p_desde text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_servicios (origen, nombre, monto, moneda, frecuencia, dia, categoria, medio, tarjeta, desde, texto_crudo)
  values (p_origen, p_nombre, p_monto, p_moneda, 'mensual', null, p_categoria,
          case when p_cobro = 'debito' then 'debito' else 'tarjeta' end,
          case when p_cobro = 'debito' then null else p_cobro end, p_desde, p_nombre);
  return query select * from etl_resumen();
end $$;

-- el pago de un resumen (tarjeta + mes del vencimiento) o de un fijo de débito (fijo + mes pagado)
create or replace function registrar_pago(p_origen text, p_fecha text, p_monto text, p_moneda text default 'ARS',
  p_tarjeta text default null, p_fijo text default null, p_mes text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_pagos (origen, fecha, monto, moneda, tipo, tarjeta, servicio, mes, texto_crudo)
  values (p_origen, p_fecha, p_monto, p_moneda, case when p_tarjeta is not null then 'resumen' else 'servicio' end,
          p_tarjeta, p_fijo, p_mes, 'pago ' || p_mes);
  return query select * from etl_resumen();
end $$;

-- la cotización del dólar de un día
create or replace function registrar_dolar(p_origen text, p_fecha text, p_valor text)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_dolar (origen, fecha, valor, texto_crudo) values (p_origen, p_fecha, p_valor, p_valor);
  return query select * from etl_resumen();
end $$;

-- nombre legible y emoji de una compra de resumen (referencia + cuotas totales; 0 si no tiene cuotas)
create or replace function nombrar_compra(p_origen text, p_referencia text, p_cuotas_totales text default '0', p_nombre text default null,
  p_emoji text default null)
returns setof jsonb language plpgsql as $$
begin
  insert into bronce_nombres_compra (origen, referencia, cuotas_totales, nombre, emoji, texto_crudo)
  values (p_origen, p_referencia, p_cuotas_totales, p_nombre, p_emoji, p_nombre);
  return query select * from etl_resumen();
end $$;
