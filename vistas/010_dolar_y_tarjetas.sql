-- Dólar vigente y los resúmenes de tarjeta (líneas cargadas de los PDF).

create or replace view oro_dolar_vigente with (security_invoker = true) as
select valor, fecha from plata_dolar order by fecha desc, id desc limit 1;

create or replace view oro_cotizacion_usd with (security_invoker = true) as
select valor, fecha from oro_dolar_vigente;

create or replace view tablero_dolar with (security_invoker = true) as
select valor, fecha from oro_dolar_vigente;

create or replace view oro_gastos_tarjeta_resumen with (security_invoker = true) as
select t.nombre as tarjeta, c.nombre as categoria, h.vencimiento, count(*) as lineas,
  sum(h.monto_ars) as total_ars, sum(h.monto_usd) as total_usd
from oro_hechos_tarjeta h
  join dim_tarjeta t on t.id = h.tarjeta_id
  join dim_categoria c on c.id = h.categoria_id
where h.tipo = 'compra'
group by t.nombre, c.nombre, h.vencimiento;

create or replace view oro_gastos_tarjeta_por_mes_categoria with (security_invoker = true) as
select mes(h.vencimiento) as periodo, c.nombre as categoria, t.nombre as tarjeta,
  sum(h.monto_ars) as total_ars, sum(h.monto_usd) as total_usd
from oro_hechos_tarjeta h
  join dim_categoria c on c.id = h.categoria_id
  join dim_tarjeta t on t.id = h.tarjeta_id
where h.tipo = 'compra'
group by 1, 2, 3;

-- cada cuota de cada compra en cuotas de los resúmenes, proyectada mes a mes
create or replace view oro_cuotas_proyectadas with (security_invoker = true) as
with series as (
  select distinct tarjeta, referencia, cuota_total, monto_ars,
    mes_mas(mes(vencimiento), -(cuota_nro - 1)) as inicial
  from plata_lineas_tarjeta
  where tipo = 'compra' and cuota_total is not null)
select s.tarjeta, s.referencia, n.k as cuota_nro, s.cuota_total, s.monto_ars,
  mes_mas(s.inicial, n.k - 1) as periodo
from series s join generate_series(1, 60) as n(k) on n.k <= s.cuota_total;

create or replace view oro_foto_mensual with (security_invoker = true) as
with meses as (select distinct mes(fecha) as mes from oro_movimientos),
pend as (select mes(vencimiento) as mes, sum(monto_ars) as pendiente_ars from oro_hechos_tarjeta where tipo = 'compra' group by 1)
select m.mes as periodo,
  'ARS' as moneda,
  coalesce((select sum(monto_ars) from oro_movimientos x where x.tipo = 'ingreso' and mes(x.fecha) = m.mes), 0) as ingresos_netos,
  coalesce((select sum(monto_ars) from oro_movimientos x where x.tipo = 'gasto' and mes(x.fecha) = m.mes), 0) as gastos_pagados,
  coalesce((select pendiente_ars from pend p where p.mes = m.mes), 0) as tarjetas_pendientes_resumen,
  coalesce((select sum(monto_ars) from oro_movimientos x where x.tipo = 'ingreso' and mes(x.fecha) = m.mes), 0)
  - coalesce((select sum(monto_ars) from oro_movimientos x where x.tipo = 'gasto' and mes(x.fecha) = m.mes), 0)
  - coalesce((select pendiente_ars from pend p where p.mes = m.mes), 0) as libre_despues_de_resumenes
from meses m;
