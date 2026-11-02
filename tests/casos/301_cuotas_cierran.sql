-- Un gasto de 1000 en 3 cuotas: las cuotas suman 1000 y caen en los tres meses desde primer_mes.
select registrar_gasto(p_origen => 'test', p_fecha => hoy()::text, p_monto => '1000', p_descripcion => 'Silla',
  p_forma => 'tarjeta', p_tarjeta => 'Prueba', p_cuotas => '3', p_primer_mes => mes_actual());
do $$ begin
  assert (select round(sum(monto_ars)::numeric, 2) from oro_compromisos_tarjeta) = 1000;
  assert (select array_agg(periodo order by cuota_nro) from oro_compromisos_tarjeta)
         = array[mes_actual(), mes_mas(mes_actual(), 1), mes_mas(mes_actual(), 2)];
  assert (select count(*) from oro_movimientos) = 0, 'un gasto con tarjeta no es movimiento hasta pagar el resumen';
  assert (select sum(monto) from tablero_pagos where periodo between mes_actual() and mes_mas(mes_actual(), 2)) = 1000,
    format('tablero_pagos suma %s', (select sum(monto) from tablero_pagos));
end $$;
