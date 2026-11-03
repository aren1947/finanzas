-- Saldar dos veces la misma deuda falla entera (no queda nada a medias en bronce).
select registrar_deuda(p_origen => 'test', p_fecha => '2026-10-01', p_persona => 'Persona B', p_concepto => 'Préstamo', p_monto => '500');
select saldar_deuda(p_origen => 'test', p_deuda_id => (select id::text from plata_deudas));
do $$ begin
  begin
    perform saldar_deuda(p_origen => 'test', p_deuda_id => (select id::text from plata_deudas));
    raise exception 'se saldó dos veces';
  exception when unique_violation then null; end;
  assert (select count(*) from bronce_saldos_deuda) = 1;
end $$;
