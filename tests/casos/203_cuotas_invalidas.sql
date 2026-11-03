-- Un gasto con tarjeta con cuotas '0' o un texto ('tres') quedaba con cuotas = 0 y no generaba ninguna cuota:
-- desaparecía del resumen, del tablero y de los movimientos, sin error. Ahora tiene que rechazarse o cerrar.
do $$ begin
  perform registrar_gasto(p_origen => 'test', p_fecha => hoy()::text, p_monto => '9000', p_descripcion => 'Heladera',
    p_forma => 'tarjeta', p_tarjeta => 'Prueba', p_cuotas => 'tres', p_primer_mes => mes_actual());
exception when raise_exception then null; -- rechazarlo está bien
end $$;
do $$ begin
  assert not exists (select 1 from plata_gastos g where not exists (select 1 from oro_compromisos_tarjeta o where o.plata_gasto_id = g.id)),
    format('un gasto con tarjeta quedó sin cuotas (%s en compromisos)', (select coalesce(sum(monto_ars), 0) from oro_compromisos_tarjeta));
end $$;
