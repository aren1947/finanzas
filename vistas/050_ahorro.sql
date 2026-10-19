-- Ahorro: cuánto entra, cuánto sale y cuánto sobra cada mes (real, en curso, proyectado), metas y dónde se va la plata.

create or replace view plata_ahorro_metas as
select m.nombre, m.monto, m.moneda, m.para, m.ya_tengo,
  (select to_char(min(x.cargado_en) at time zone 'America/Argentina/Buenos_Aires', 'YYYY-MM') from bronce_ahorro_metas x
   where lower(x.nombre) = lower(m.nombre)
     and x.id > coalesce((select max(z.id) from bronce_ahorro_metas z where lower(z.nombre) = lower(m.nombre) and z.monto = 0), 0)) as desde
from bronce_ahorro_metas m
where m.id = (select max(y.id) from bronce_ahorro_metas y where lower(y.nombre) = lower(m.nombre)) and m.monto > 0;

-- lo usual sale de los últimos 90 días (o desde el primer gasto): contado todos los meses, tarjeta desde el segundo mes
create or replace view tablero_ahorro as
with h as (
  select mes_actual() as mes, hoy() as hoy,
    extract(day from hoy())::double precision / extract(day from date_trunc('month', hoy()) + interval '1 month - 1 day')::double precision as ritmo,
    (select neto_ars from plata_sueldo order by fecha_cobro desc, id desc limit 1) as sueldo,
    (select min(mes(fecha_cobro)) from plata_sueldo) as primer_sueldo),
d as (
  select coalesce(case when min(fecha) is null then null
                       else greatest(hoy() - 90, date_trunc('month', min(fecha))::date) end, hoy()) as desde
  from plata_gastos),
r as (
  select greatest(1, h.hoy - d.desde + 1) as dias,
    coalesce((select sum(g.monto_ars) from plata_gastos g join dim_medio md on md.id = g.medio_id
              where g.fecha between d.desde and h.hoy and md.nombre not in ('tarjeta', 'compartido')), 0) as contado,
    coalesce((select sum(g.monto_ars) from plata_gastos g join dim_medio md on md.id = g.medio_id
              where g.fecha between d.desde and h.hoy and md.nombre = 'tarjeta'), 0) as tarjeta
  from h, d),
p as (select dias, contado / dias * 30.4 as contado_mes, tarjeta / dias * 30.4 as tarjeta_mes from r),
x as (
  select k, mes_mas(h.mes, k) as periodo
  from h, generate_series(mes_diff(coalesce(h.primer_sueldo, h.mes), h.mes), 24) as k),
v as (
  select x.k, x.periodo,
    (select sum(o.monto_ars) from oro_movimientos o where o.tipo = 'ingreso' and mes(o.fecha) = x.periodo) as ingreso_real,
    coalesce((select sum(o.monto_ars) from oro_movimientos o where o.tipo = 'gasto' and mes(o.fecha) = x.periodo), 0) as salio,
    coalesce((select t.total_ars from tablero_proximos t where t.periodo = x.periodo),
             (select t.total_ars from tablero_proximos t order by t.periodo desc limit 1)) as comprometido,
    coalesce((select t.falta_pagar from tablero_resumen t where t.periodo = x.periodo), 0) as falta_pagar,
    coalesce((select sum(pv.monto) from tablero_previstos pv where pv.periodo = x.periodo), 0) as previsto,
    (select b.monto from bronce_ahorro_minimo b where b.desde <= x.periodo order by b.desde desc, b.id desc limit 1) as minimo
  from x),
w as (
  select v.*, h.sueldo, h.ritmo, p.dias, p.contado_mes, p.tarjeta_mes,
    case when v.k < 0 then 'real' when v.k = 0 then 'en curso' else 'proyectado' end as estado,
    case when v.k <= 0 and v.ingreso_real is not null then v.ingreso_real else h.sueldo end as ingreso,
    case when v.k <= 0 and v.ingreso_real is not null then 0 else 1 end as ingreso_supuesto,
    case when v.k < 0 then 0
         when v.k = 0 then p.contado_mes * (1 - h.ritmo)
         else p.contado_mes + case when v.k >= 2 then p.tarjeta_mes else 0 end end as variable
  from v, h, p)
select periodo, k, estado, round(ingreso, 2) as ingreso, ingreso_supuesto,
  round(case when k < 0 then salio when k = 0 then salio + falta_pagar + variable + previsto else comprometido + variable + previsto end, 2) as sale,
  round(case when k = 0 then salio else null end, 2) as ya_salio,
  round(case when k < 0 then null when k = 0 then falta_pagar else comprometido end, 2) as comprometido,
  round(variable, 2) as variable,
  round(case when k < 0 then 0 else previsto end, 2) as previsto,
  round(ingreso - case when k < 0 then salio when k = 0 then salio + falta_pagar + variable + previsto else comprometido + variable + previsto end, 2) as sobra,
  nullif(minimo, 0) as minimo,
  dias::integer as dias_datos
from w
order by k;

-- cada meta: si llega a tiempo, cuándo llega, o cuánto recortar por mes
create or replace view tablero_ahorro_metas as
with g as (
  select a.*,
    round(case when a.moneda = 'USD' then a.monto * (select valor from oro_dolar_vigente) else a.monto end, 2) as objetivo_ars,
    round(case when a.moneda = 'USD' then a.ya_tengo * (select valor from oro_dolar_vigente) else a.ya_tengo end, 2) as ya_tengo_ars
  from plata_ahorro_metas a),
s as (
  select g.nombre,
    (select count(*) from tablero_ahorro t where t.periodo between g.desde and g.para) as meses,
    (select count(*) from tablero_ahorro t where t.k >= 0 and t.periodo between g.desde and g.para) as meses_que_quedan,
    g.ya_tengo_ars + coalesce((select sum(t.sobra) from tablero_ahorro t where t.periodo between g.desde and g.para), 0) as juntas,
    coalesce((select sum(t.variable) from tablero_ahorro t where t.k >= 0 and t.periodo between g.desde and g.para), 0) as variable_hasta,
    (select min(t.periodo) from tablero_ahorro t
     where t.periodo >= g.desde
       and g.ya_tengo_ars + (select sum(u.sobra) from tablero_ahorro u where u.periodo between g.desde and t.periodo) >= g.objetivo_ars) as llega_en
  from g)
select g.nombre, g.monto, g.moneda, g.ya_tengo, g.objetivo_ars, g.ya_tengo_ars, g.desde, g.para, s.meses,
  round(smax(g.objetivo_ars - g.ya_tengo_ars, 0) / smax(s.meses, 1), 2) as por_mes,
  round(s.juntas, 2) as juntas_para_entonces, s.llega_en,
  case when s.juntas >= g.objetivo_ars then 'llega'
       when s.juntas + s.variable_hasta >= g.objetivo_ars then 'recortando'
       else 'no_llega' end as estado,
  round(smax(g.objetivo_ars - s.juntas, 0) / smax(s.meses_que_quedan, 1), 2) as recorte_por_mes
from g join s on s.nombre = g.nombre
order by g.para, g.nombre;

-- dónde se va la plata por mes (lo usual de los últimos 90 días), con su límite si tiene
create or replace view tablero_ahorro_categorias as
with d as (
  select coalesce(case when min(fecha) is null then null
                       else greatest(hoy() - 90, date_trunc('month', min(fecha))::date) end, hoy()) as desde
  from plata_gastos),
r as (select greatest(1, hoy() - d.desde + 1) as dias from d)
select c.nombre as categoria, c.emoji, round(sum(g.monto_ars) / r.dias * 30.4, 2) as por_mes,
  (select pr.limite from plata_presupuestos pr where pr.categoria_id = c.id) as limite
from plata_gastos g
  join dim_categoria c on c.id = g.categoria_id
  join dim_medio md on md.id = g.medio_id,
  d, r
where g.fecha between d.desde and hoy() and md.nombre <> 'compartido'
group by c.id, r.dias
order by por_mes desc;
