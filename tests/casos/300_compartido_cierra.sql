-- Gasto compartido: mi parte es gasto, la del otro es deuda, y todo cierra (incluido el redondeo de la mitad).
select registrar_compartido(p_origen => 'test', p_persona => 'Persona A', p_descripcion => 'Cena', p_categoria => 'Salidas',
  p_total => 100.01, p_fecha => '2026-10-10', p_pago => 'yo', p_medio => 'debito');
select registrar_compartido(p_origen => 'test', p_persona => 'Persona A', p_descripcion => 'Cine', p_categoria => 'Salidas',
  p_total => 3000, p_fecha => '2026-10-11', p_pago => 'otro', p_mi_porcentaje => 40);
do $$
declare d1 int; d2 int;
begin
  -- pagué yo 100.01: gasto 50.01 + me deben 50.00
  assert (select round(sum(monto_ars)::numeric, 2) from plata_gastos) = 50.01 + 1200, 'mis partes no suman';
  assert (select round(monto::numeric, 2) from plata_deudas where concepto = 'Cena' and sentido = 'me_deben') = 50.00;
  assert (select round(monto::numeric, 2) from plata_deudas where concepto = 'Cine' and sentido = 'le_debo') = 1200;
  assert (select round(sum(monto_ars)::numeric, 2) from oro_movimientos where tipo = 'gasto') = 1250.01, 'los movimientos no cierran';
  assert (select sum(monto_ars) from oro_movimientos_cuenta where ref like 'comp:%') = 100.01, 'la cuenta no muestra el total pagado';
  select id into d1 from plata_deudas where concepto = 'Cena';
  select id into d2 from plata_deudas where concepto = 'Cine';
  perform pagar_deuda(p_origen => 'test', p_deuda_id => d1, p_monto => 50, p_fecha => '2026-10-12');
  assert (select estado from tablero_deudas where clave = 'deuda:' || d1) = 'saldada', 'Cena no quedó saldada';
  begin
    perform compensar_deuda(p_origen => 'test', p_deuda_id => d2, p_contra_deuda_id => d1);
    raise exception 'compensó contra una deuda ya saldada';
  exception when raise_exception then
    if sqlerrm not like 'no hay nada para compensar%' then raise; end if;
  end;
  assert (select resta from tablero_deudas where clave = 'deuda:' || d2) = 1200, 'Cine no debería cambiar';
  -- pagar la deuda no es otro gasto
  assert (select round(sum(monto_ars)::numeric, 2) from oro_movimientos where tipo = 'gasto') = 1250.01, 'pagar la deuda sumó gasto';
end $$;
