-- num() toma el número del principio con punto decimal: '1.500' (mil quinientos, como se escribe acá) queda 1,5
-- y '1.234,56' queda 1,234. No falla: guarda el monto mal.
do $$ begin
  perform registrar_gasto(p_origen => 'test', p_fecha => '2026-10-01', p_monto => '1.500', p_descripcion => 'Algo', p_medio => 'efectivo');
exception when others then null; -- rechazarlo también está bien
end $$;
do $$ begin
  assert not exists (select 1 from plata_gastos where monto_ars < 100),
    format('un gasto de "1.500" quedó en %s', (select monto_ars from plata_gastos limit 1));
end $$;
