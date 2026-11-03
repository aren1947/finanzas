-- La misma compra cargada a mano (registrar_gasto con tarjeta) y después llegada en el PDF del resumen
-- figura dos veces en el detalle del resumen y, al pagarlo, cuenta doble como gasto.
select registrar_gasto(p_origen => 'test', p_fecha => hoy()::text, p_monto => '1000', p_descripcion => 'Super',
  p_categoria => 'Super', p_forma => 'tarjeta', p_tarjeta => 'Prueba', p_cuotas => '1', p_primer_mes => mes_actual());
insert into bronce_resumenes_lineas (origen, tarjeta, vencimiento, fecha_texto, referencia, cuota, comprobante, pesos_texto, dolares_texto)
values ('pdf', 'TARJ PRUEBA', to_char(hoy() + 5, 'DD/MM/YY'), to_char(hoy(), 'DD/MM/YY'), 'SUPER SA', '', '123', '1.000,00', '');
select correr_etl();
select registrar_pago(p_origen => 'test', p_fecha => hoy()::text, p_monto => '1000', p_tarjeta => 'Prueba', p_mes => mes(hoy() + 5));
do $$ begin
  assert (select sum(monto_ars) from oro_movimientos where tipo = 'gasto') = 1000,
    format('pagué 1000 y figuran %s de gasto', (select sum(monto_ars) from oro_movimientos where tipo = 'gasto'));
end $$;
