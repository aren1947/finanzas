-- Dos gastos con tarjeta con la misma descripción en el mismo resumen: al pagarlo, oro_resumen_items
-- (único por plata_pago_id + descripcion) choca y el pago no se puede registrar.
select registrar_gasto(p_origen => 'test', p_fecha => hoy()::text, p_monto => '1000', p_descripcion => 'Uber',
  p_forma => 'tarjeta', p_tarjeta => 'Prueba', p_cuotas => '1', p_primer_mes => mes_actual());
select registrar_gasto(p_origen => 'test', p_fecha => hoy()::text, p_monto => '2000', p_descripcion => 'Uber',
  p_forma => 'tarjeta', p_tarjeta => 'Prueba', p_cuotas => '1', p_primer_mes => mes_actual());
select registrar_pago(p_origen => 'test', p_fecha => hoy()::text, p_monto => '3000', p_tarjeta => 'Prueba', p_mes => mes_actual());
do $$ begin
  assert (select sum(monto_ars) from oro_movimientos where tipo = 'gasto') = 3000, 'el resumen pagado no suma 3000';
end $$;
