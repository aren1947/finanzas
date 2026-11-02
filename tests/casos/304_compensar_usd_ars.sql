-- Compensar una deuda en dólares contra una en pesos con la misma persona: convierte con el dólar del día y nunca pasa lo que resta.
select registrar_dolar(p_origen => 'test', p_fecha => '2026-10-01', p_valor => '1000');
select registrar_deuda(p_origen => 'test', p_fecha => '2026-10-02', p_persona => 'Persona C', p_concepto => 'Pasaje',
  p_monto => '100', p_moneda => 'USD', p_sentido => 'me_deben');
select registrar_deuda(p_origen => 'test', p_fecha => '2026-10-03', p_persona => 'Persona C', p_concepto => 'Asado',
  p_monto => '30000', p_moneda => 'ARS', p_sentido => 'le_debo');
select compensar_deuda(p_origen => 'test', p_deuda_id => (select id from plata_deudas where concepto = 'Pasaje'),
  p_contra_deuda_id => (select id from plata_deudas where concepto = 'Asado'), p_fecha => '2026-10-04');
do $$ begin
  assert (select resta from tablero_deudas where concepto = 'Pasaje') = 70, 'el pasaje no quedó en USD 70';
  assert (select estado from tablero_deudas where concepto = 'Asado') = 'saldada', 'el asado no quedó saldado';
end $$;
