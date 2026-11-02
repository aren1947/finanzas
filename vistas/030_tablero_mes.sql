-- El mes en el tablero: en qué se fue la plata, lo que falta pagar, las series para los gráficos y los movimientos.

create or replace view tablero_categorias with (security_invoker = true) as
select mes(m.fecha) as periodo, c.nombre as categoria, c.emoji, round(sum(m.monto_ars), 2) as monto
from oro_movimientos m join dim_categoria c on c.id = m.categoria_id
where m.tipo = 'gasto'
group by 1, 2, 3;

create or replace view tablero_resumen with (security_invoker = true) as
with ms as (select mes_mas('2026-01', g) as p from generate_series(0, greatest(mes_diff(mes_mas(mes_actual(), 6), '2026-01'), 0)) as g),
reales as (select mes(fecha) as p, sum(monto_ars) as r from oro_movimientos where tipo = 'gasto' group by 1)
select ms.p as periodo, round(coalesce(reales.r, 0), 2) as realizado,
  round(coalesce((select sum(c.monto_ars) from oro_compromisos_mes c
                  where c.periodo = ms.p and c.pagado = 0 and c.periodo >= mes_actual()), 0), 2) as falta_pagar
from ms left join reales on reales.p = ms.p;

create or replace view tablero_series with (security_invoker = true) as
with ms as (select mes_mas('2026-01', g) as p from generate_series(0, greatest(mes_diff(mes_mas(mes_actual(), 6), '2026-01'), 0)) as g)
select 'total' as serie_tipo, 'Total gastado' as serie, '📊' as emoji, periodo, realizado as monto, 'ARS' as moneda from tablero_resumen
union all
select 'categoria', categoria, emoji, periodo, monto, 'ARS' from tablero_categorias
union all
select 'fijo', s.nombre, cat.emoji, ms.p, pf.monto, pf.moneda
from ms cross join plata_servicios s
  join dim_categoria cat on cat.id = s.categoria_id
  join plata_precios_fijo pf on pf.servicio_id = s.id
    and pf.desde = (select max(x.desde) from plata_precios_fijo x where x.servicio_id = s.id and x.desde <= ms.p)
where s.activa = 1
union all
select 'sueldo', 'Sueldo neto', '💰', mes(m.fecha), round(sum(m.monto_ars), 2), 'ARS'
from oro_movimientos m where m.tipo = 'ingreso' group by mes(m.fecha)
union all
select 'tarjeta', t.nombre_visible, '💳', c.periodo, round(sum(c.monto_ars), 2), 'ARS'
from oro_compromisos_mes c join dim_tarjeta t on 'tarjeta:' || t.id = c.clave
where c.tipo = 'tarjeta' group by t.nombre_visible, c.periodo;

create or replace view tablero_pagos with (security_invoker = true) as
select c.periodo, c.clave, c.tipo,
  case c.tipo when 'fijo' then max(c.nombre) else coalesce(max(t.nombre_visible), max(c.nombre_pago)) end as nombre,
  max(c.emoji_pago) as emoji,
  case c.tipo when 'tarjeta' then 'vence el ' || max(t.vence_dia) || ' · ' || count(*) || case when count(*) = 1 then ' compra' else ' compras' end
              else 'mensual' end as detalle,
  case c.tipo when 'fijo' then max(c.monto) else round(sum(c.monto_ars), 2) end as monto,
  case c.tipo when 'fijo' then max(c.moneda) else 'ARS' end as moneda,
  max(c.pagado) as pagado
from oro_compromisos_mes c left join dim_tarjeta t on 'tarjeta:' || t.id = c.clave
where c.periodo >= mes_actual()
group by c.periodo, c.clave, c.tipo
order by c.periodo, c.tipo, c.clave;

create or replace view tablero_tarjeta with (security_invoker = true) as
select d.clave, d.periodo, d.nombre, coalesce(cat.emoji, '💳') as emoji,
  case when d.origen = 'servicio' then 'mensual' else d.detalle end as detalle,
  round(d.monto, 2) as monto, d.moneda, d.estado
from oro_resumenes_detalle d left join dim_categoria cat on cat.nombre = d.categoria
where d.periodo >= mes_actual()
order by d.periodo, d.clave, d.nombre;

-- los últimos 100 movimientos, con un nombre legible y cómo se pagó
create or replace view tablero_movimientos with (security_invoker = true) as
select clave, fecha, tipo, descripcion, emoji, categoria, medio, monto, moneda, cotizacion from (
  select 'mov:' || m.id as clave, m.fecha, m.tipo,
    case
      when m.origen_tabla = 'plata_sueldo' then 'Sueldo'
      when m.origen_tabla = 'plata_pagos' and m.tarjeta_id is null
        then 'Pago ' || coalesce((select ps.nombre from plata_pagos p join plata_servicios ps on ps.id = p.servicio_id where p.id = m.origen_id), '')
      when m.origen_tabla = 'oro_resumen_items' and strpos(m.descripcion, ' · ') > 0
        then substr(m.descripcion, 1, strpos(m.descripcion, ' · ') - 1)
      else m.descripcion end as descripcion,
    c.emoji, c.nombre as categoria,
    case when m.tarjeta_id is not null then dt.nombre_visible when m.origen_tabla = 'plata_gastos' then 'Contado'
         when m.origen_tabla = 'plata_pagos' then 'Débito automático' else 'Sueldo' end as medio,
    case when g.moneda = 'USD' then g.monto_usd else m.monto_ars end as monto,
    case when g.moneda = 'USD' then 'USD' else 'ARS' end as moneda,
    case when g.moneda = 'USD' then g.tipo_cambio end as cotizacion,
    m.id as orden_id
  from oro_movimientos m
    join dim_categoria c on c.id = m.categoria_id
    left join plata_gastos g on m.origen_tabla = 'plata_gastos' and g.id = m.origen_id
    left join dim_tarjeta dt on dt.id = m.tarjeta_id
  order by m.fecha desc, m.id desc limit 100
) ultimos
order by fecha desc, orden_id desc;
