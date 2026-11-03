-- Presupuestos por categoría y previstos (gastos pensados pero no seguros).

create or replace view plata_presupuestos with (security_invoker = true) as
select c.id as categoria_id, c.nombre as categoria, c.emoji, b.monto as limite, b.desde
from bronce_presupuestos b join dim_categoria c on c.nombre = b.categoria
where b.id = (select max(x.id) from bronce_presupuestos x where x.categoria = b.categoria) and b.monto > 0;

-- ritmo: qué parte del mes pasó (1 en los meses pasados)
create or replace view tablero_presupuestos with (security_invoker = true) as
with h as (select mes_actual() as mes, extract(day from hoy())::double precision as dia,
             extract(day from date_trunc('month', hoy()) + interval '1 month - 1 day')::double precision as dias),
meses as (select distinct mes(fecha) as periodo from plata_gastos union select mes from h)
select m.periodo, p.categoria, p.emoji, p.limite,
  round(coalesce((select sum(g.monto_ars) from plata_gastos g where g.categoria_id = p.categoria_id and mes(g.fecha) = m.periodo), 0), 2) as gastado,
  case when m.periodo = h.mes then round(h.dia / h.dias, 3) when m.periodo < h.mes then 1 else 0 end as ritmo
from plata_presupuestos p join meses m on m.periodo >= p.desde cross join h
where m.periodo <= h.mes;

create or replace view plata_previstos with (security_invoker = true) as
select p.id, p.descripcion, p.monto, p.categoria, p.periodo as periodo_original,
  coalesce((select c.periodo from bronce_previstos_cambios c where c.previsto_id = p.id and c.accion = 'postergar' order by c.id desc limit 1),
           p.periodo) as periodo,
  coalesce((select case c.accion when 'confirmar' then 'confirmado' else 'descartado' end from bronce_previstos_cambios c
            where c.previsto_id = p.id and c.accion in ('confirmar', 'descartar') limit 1), 'pendiente') as estado,
  (select count(*) from bronce_previstos_cambios c where c.previsto_id = p.id and c.accion = 'postergar') as postergado
from bronce_previstos p;

create or replace view tablero_previstos with (security_invoker = true) as
select v.id, v.periodo, v.descripcion, v.monto, v.categoria, d.emoji, v.postergado,
  case when v.periodo < mes_actual() then 1 else 0 end as vencido
from plata_previstos v left join dim_categoria d on d.nombre = v.categoria and d.tipo = 'egreso'
where v.estado = 'pendiente'
order by v.periodo, v.id;

-- lo comprometido de cada uno de los próximos 7 meses, y lo previsto
create or replace view tablero_proximos with (security_invoker = true) as
with meses as (select mes_mas(mes_actual(), k) as periodo from generate_series(0, 6) as m(k))
select me.periodo,
  round(coalesce(sum(case when c.moneda = 'ARS' then c.monto end), 0), 2) as ars,
  round(coalesce(sum(case when c.moneda = 'USD' then c.monto end), 0), 2) as usd,
  round(coalesce(sum(c.monto_ars), 0), 2) as total_ars,
  (select round(coalesce(sum(p.monto), 0), 2) from tablero_previstos p where p.periodo = me.periodo) as previsto
from meses me left join oro_compromisos_mes c on c.periodo = me.periodo
group by me.periodo
order by me.periodo;
