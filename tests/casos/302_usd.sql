-- Gasto en dólares: usa la cotización de la carga o la del día; sin ninguna, la carga falla (no queda en cero).
select registrar_dolar(p_origen => 'test', p_fecha => '2026-10-01', p_valor => '1000');
select registrar_gasto(p_origen => 'test', p_fecha => '2026-10-05', p_monto => '10', p_moneda => 'USD', p_descripcion => 'App', p_medio => 'debito');
do $$ begin
  assert (select monto_ars from plata_gastos) = 10000;
  assert (select tipo_cambio from plata_gastos) = 1000;
  begin
    perform registrar_gasto(p_origen => 'test', p_fecha => '2026-09-01', p_monto => '10', p_moneda => 'USD', p_medio => 'debito');
    raise exception 'un gasto en USD sin cotización se cargó igual';
  exception when not_null_violation then null; end;
end $$;
