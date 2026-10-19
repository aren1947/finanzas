-- Lo que viene a pagar en los próximos 7 meses: cada resumen de tarjeta con su detalle, y los fijos.

-- el detalle de cada resumen de tarjeta: líneas de PDF, cuotas proyectadas, gastos con tarjeta cargados a mano y fijos con tarjeta
create or replace view oro_resumenes_detalle as
with meses as (select mes_mas(mes_actual(), k) as periodo from generate_series(0, 6) as m(k)),
ultimo_venc as (select coalesce(max(mes(vencimiento)), '0000-00') as mv from plata_lineas_tarjeta)
select * from (
  select mes(p.vencimiento) as periodo, t.id as tarjeta_id, 'tarjeta:' || t.id as clave,
    coalesce(c.nombre, p.referencia) as nombre, coalesce(c.emoji, '💳') as emoji,
    'compra del ' || to_char(p.fecha, 'DD/MM') as detalle,
    case when p.monto_usd <> 0 then 'USD' else 'ARS' end as moneda,
    case when p.monto_usd <> 0 then p.monto_usd else p.monto_ars end as monto,
    'terminada' as estado, 'linea' as origen, coalesce(cc.nombre, 'Otros') as categoria,
    case when p.monto_usd <> 0 then p.monto_usd * (select valor from oro_dolar_vigente) else p.monto_ars end as monto_ars
  from plata_lineas_tarjeta p
    join dim_tarjeta t on t.nombre = p.tarjeta
    left join dim_comercio c on c.referencia = p.referencia and c.cuotas_totales = 0
    left join dim_categoria cc on cc.id = c.categoria_id
  where p.tipo = 'compra' and p.cuota_total is null
  union all
  select o.periodo, t.id, 'tarjeta:' || t.id, coalesce(c.nombre, o.referencia), coalesce(c.emoji, '💳'),
    'cuota ' || o.cuota_nro || ' de ' || o.cuota_total || ' · quedan ' || (o.cuota_total - o.cuota_nro),
    'ARS', o.monto_ars, case when o.cuota_nro = o.cuota_total then 'terminada' else 'activa' end, 'cuota', coalesce(cc.nombre, 'Otros'),
    o.monto_ars
  from oro_cuotas_proyectadas o
    join dim_tarjeta t on t.nombre = o.tarjeta
    left join dim_comercio c on c.referencia = o.referencia and c.cuotas_totales = o.cuota_total
    left join dim_categoria cc on cc.id = c.categoria_id
  union all
  select oc.periodo, oc.tarjeta_id, 'tarjeta:' || oc.tarjeta_id, g.descripcion, cat.emoji,
    case when oc.cuota_total > 1 then 'cuota ' || oc.cuota_nro || ' de ' || oc.cuota_total || ' · quedan ' || (oc.cuota_total - oc.cuota_nro) else 'compra' end,
    g.moneda, case when g.moneda = 'USD' then oc.monto_usd else oc.monto_ars end,
    case when oc.cuota_nro = oc.cuota_total then 'terminada' else 'activa' end, 'manual', cat.nombre,
    oc.monto_ars
  from oro_compromisos_tarjeta oc
    join plata_gastos g on g.id = oc.plata_gasto_id
    join dim_categoria cat on cat.id = oc.categoria_id
  union all
  select me.periodo, s.tarjeta_id, 'tarjeta:' || s.tarjeta_id, s.nombre, cat.emoji, 'cargo del mes anterior · ' || s.frecuencia,
    pf.moneda, pf.monto, 'activa', 'servicio', cat.nombre,
    case when pf.moneda = 'USD' then pf.monto * coalesce(pf.tipo_cambio, (select valor from oro_dolar_vigente)) else pf.monto end
  from meses me
    cross join plata_servicios s
    join dim_categoria cat on cat.id = s.categoria_id
    cross join ultimo_venc uv
    join plata_precios_fijo pf on pf.servicio_id = s.id
      and pf.desde = (select max(x.desde) from plata_precios_fijo x where x.servicio_id = s.id and x.desde <= me.periodo)
  where s.activa = 1 and s.medio_id = (select id from dim_medio where nombre = 'tarjeta') and me.periodo > uv.mv
);

-- cada pago del mes: un resumen por tarjeta (con su detalle) y cada fijo que no se paga con tarjeta
create or replace view oro_compromisos_mes as
with meses as (select mes_mas(mes_actual(), k) as periodo from generate_series(0, 6) as m(k))
select d.periodo, d.clave, 'tarjeta' as tipo, t.nombre_visible as nombre_pago, '💳' as emoji_pago,
  d.nombre, d.emoji, d.detalle, d.moneda, d.monto,
  d.monto_ars,
  case when exists (select 1 from plata_pagos p where p.tipo = 'resumen' and p.tarjeta_id = d.tarjeta_id and p.mes = d.periodo) then 1 else 0 end as pagado,
  d.estado
from oro_resumenes_detalle d join dim_tarjeta t on t.id = d.tarjeta_id
union all
select me.periodo, 'fijo:' || s.id, 'fijo', s.nombre, cat.emoji, s.nombre, cat.emoji, 'mensual', pf.moneda, pf.monto,
  case when pf.moneda = 'USD' then pf.monto * coalesce(pf.tipo_cambio, (select valor from oro_dolar_vigente)) else pf.monto end,
  case when exists (select 1 from plata_pagos p where p.tipo = 'servicio' and p.servicio_id = s.id and p.mes = me.periodo) then 1 else 0 end,
  'activa'
from meses me
  cross join plata_servicios s
  join dim_categoria cat on cat.id = s.categoria_id
  join plata_precios_fijo pf on pf.servicio_id = s.id
    and pf.desde = (select max(x.desde) from plata_precios_fijo x where x.servicio_id = s.id and x.desde <= me.periodo)
where s.activa = 1 and s.medio_id <> (select id from dim_medio where nombre = 'tarjeta');
