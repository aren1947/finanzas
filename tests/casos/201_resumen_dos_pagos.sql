-- Un resumen pagado en dos partes (o la parte en dólares aparte): plata_pagos.clave es única por tarjeta y mes.
select registrar_pago(p_origen => 'test', p_fecha => hoy()::text, p_monto => '1000', p_tarjeta => 'Prueba', p_mes => mes_actual());
select registrar_pago(p_origen => 'test', p_fecha => hoy()::text, p_monto => '500', p_tarjeta => 'Prueba', p_mes => mes_actual());
do $$ begin
  assert (select sum(monto_ars) from plata_pagos) = 1500;
end $$;
