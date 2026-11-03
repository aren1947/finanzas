-- Las fechas de bronce se pasan a date con ::date, que depende de DateStyle (Supabase: ISO, MDY):
-- '02/11/2026' (2 de noviembre) queda 11 de febrero, sin error.
do $$ begin
  perform registrar_gasto(p_origen => 'test', p_fecha => '02/11/2026', p_monto => '1000', p_descripcion => 'Algo', p_medio => 'efectivo');
exception when others then null; -- rechazarlo también está bien
end $$;
do $$ begin
  assert not exists (select 1 from plata_gastos where fecha = '2026-02-11'),
    'el 2/11 quedó como 11 de febrero';
end $$;
