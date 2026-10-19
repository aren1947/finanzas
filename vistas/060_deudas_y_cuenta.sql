-- Deudas, gastos compartidos, sueldo, opciones para los formularios y los movimientos de la cuenta bancaria.

create or replace view tablero_sueldo as
select fecha_cobro, bruto_ars, retencion_pct, neto_ars from plata_sueldo order by fecha_cobro desc, id desc;

create or replace view tablero_compartidos as
select substr(c.fecha, 1, 7) as periodo, 'comp:' || c.id as clave, c.fecha, c.persona, c.descripcion, c.categoria, cat.emoji,
  c.total, c.mi_parte, c.pago, 'deuda:' || d.id as deuda, d.monto as deuda_monto,
  case d.sentido when 'me_deben' then 'te_deben' when 'le_debo' then 'debes' end as sentido,
  case when s.id is null then 0 else 1 end as saldada
from bronce_compartidos c
  left join dim_categoria cat on cat.nombre = c.categoria
  left join plata_deudas d on d.origen = 'bronce_compartidos' and d.bronce_id = c.id
  left join plata_saldos_deuda s on s.deuda_id = d.id;

-- lo que resta de cada deuda: el monto menos los pagos parciales y las compensaciones
create or replace view tablero_deudas as
with r as (
  select d.*, round(d.monto - coalesce((select sum(x.monto) from plata_pagos_deuda x where x.deuda_id = d.id), 0)
                            - coalesce((select sum(x.monto) from plata_compensaciones_deuda x where x.deuda_id = d.id), 0), 2) as resta
  from plata_deudas d)
select 'deuda:' || d.id as clave, d.fecha, p.nombre as persona, d.concepto, d.monto, d.moneda,
  case d.sentido when 'me_deben' then 'te_deben' else 'debes' end as sentido,
  d.resta,
  case when s.id is not null or d.resta <= 0.005 then 1 else 0 end as saldada,
  case when bs.texto_crudo = 'olvidada' then 'olvidada' when s.id is not null or d.resta <= 0.005 then 'saldada' else 'abierta' end as estado,
  case when d.origen = 'bronce_compartidos' then 'compartido' else 'prestamo' end as tipo,
  round(case when d.moneda = 'USD' then d.resta * (select valor from oro_dolar_vigente) else d.resta end, 2) as resta_ars
from r d
  join dim_persona p on p.id = d.persona_id
  left join plata_saldos_deuda s on s.deuda_id = d.id
  left join bronce_saldos_deuda bs on bs.id = s.bronce_id;

-- las opciones de los formularios, las más usadas primero
create or replace view tablero_opciones as
select tipo, valor, emoji, usos from (
  select 'categoria' as tipo, c.nombre as valor, c.emoji,
    (select count(*) from oro_movimientos m where m.categoria_id = c.id)
    + (select count(*) from oro_compromisos_tarjeta o where o.categoria_id = c.id)
    + (select count(*) from plata_servicios s where s.categoria_id = c.id) as usos,
    c.id as orden
  from dim_categoria c where c.tipo = 'egreso'
  union all
  select 'tarjeta', t.nombre_visible, '💳',
    (select count(*) from oro_compromisos_tarjeta o where o.tarjeta_id = t.id)
    + (select count(*) from plata_pagos p where p.tarjeta_id = t.id)
    + (select count(*) from plata_servicios s where s.tarjeta_id = t.id),
    t.id
  from dim_tarjeta t where t.nombre_visible is not null
  union all
  select 'persona', p.nombre, '👤', (select count(*) from plata_deudas d where d.persona_id = p.id), p.id from dim_persona p
) o
order by tipo, usos desc, orden;

-- lo que entra y sale de la cuenta bancaria (no la tarjeta)
create or replace view oro_movimientos_cuenta as
select g.fecha, 'sale' as sentido, round(g.monto_ars, 2) as monto_ars, g.descripcion, m.nombre as origen, 'gasto:' || g.id as ref
from plata_gastos g join dim_medio m on m.id = g.medio_id
where m.nombre in ('debito', 'transferencia') and g.origen = 'bronce_gastos'
union all
select p.fecha, 'sale', round(p.monto_ars, 2),
  case p.tipo when 'resumen' then 'Pago resumen ' || coalesce(t.nombre_visible, '') || ' ' || p.mes
              else 'Débito ' || coalesce(s.nombre, '') || ' ' || p.mes end,
  case p.tipo when 'resumen' then 'pago_tarjeta' else 'pago_fijo' end, 'pago:' || p.id
from plata_pagos p left join dim_tarjeta t on t.id = p.tarjeta_id left join plata_servicios s on s.id = p.servicio_id
union all
select fecha_cobro, 'entra', round(neto_ars, 2), 'Sueldo neto', 'sueldo', 'sueldo:' || id from plata_sueldo
union all
select c.fecha::date, 'sale', round(c.total, 2), c.descripcion || ' (compartido con ' || c.persona || ', total)', 'compartido', 'comp:' || c.id
from bronce_compartidos c where c.pago = 'yo' and c.medio in ('debito', 'transferencia')
union all
select d.fecha, case d.sentido when 'me_deben' then 'sale' else 'entra' end, round(d.monto, 2),
  'Préstamo: ' || d.concepto || ' (' || pe.nombre || ')', 'prestamo', 'deuda:' || d.id
from plata_deudas d join dim_persona pe on pe.id = d.persona_id
where d.origen = 'bronce_deudas' and d.moneda = 'ARS'
union all
select x.fecha, case d.sentido when 'me_deben' then 'entra' else 'sale' end, round(x.monto, 2),
  'Parte de deuda: ' || d.concepto || ' (' || pe.nombre || ')', 'pago_deuda', 'pagodeuda:' || x.id
from plata_pagos_deuda x join plata_deudas d on d.id = x.deuda_id join dim_persona pe on pe.id = d.persona_id
where d.moneda = 'ARS'
union all
select s.fecha, case d.sentido when 'me_deben' then 'entra' else 'sale' end,
  round(d.monto - coalesce((select sum(x.monto) from plata_pagos_deuda x where x.deuda_id = d.id and x.fecha <= s.fecha), 0)
                - coalesce((select sum(x.monto) from plata_compensaciones_deuda x where x.deuda_id = d.id and x.fecha <= s.fecha), 0), 2),
  'Saldó deuda: ' || d.concepto || ' (' || pe.nombre || ')', 'saldo_deuda', 'saldo:' || s.id
from plata_saldos_deuda s
  join plata_deudas d on d.id = s.deuda_id
  join dim_persona pe on pe.id = d.persona_id
  join bronce_saldos_deuda bs on bs.id = s.bronce_id
where coalesce(bs.texto_crudo, '') <> 'olvidada' and d.moneda = 'ARS'
  and d.monto - coalesce((select sum(x.monto) from plata_pagos_deuda x where x.deuda_id = d.id and x.fecha <= s.fecha), 0)
              - coalesce((select sum(x.monto) from plata_compensaciones_deuda x where x.deuda_id = d.id and x.fecha <= s.fecha), 0) > 0.005;
