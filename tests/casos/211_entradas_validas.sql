-- Las validaciones de procedimientos/000 dejan pasar lo que manda Aren hoy (ISO, punto decimal) y cortan lo ambiguo.
select registrar_dolar(p_origen => 'test', p_fecha => '2026-10-01', p_valor => '1450.50');
select registrar_gasto(p_origen => 'test', p_fecha => '2026-10-19', p_monto => '1000', p_descripcion => 'Precintos', p_medio => 'efectivo');
select registrar_gasto(p_origen => 'test', p_fecha => '2026-10-19', p_monto => ' 1500.5 ', p_descripcion => 'Otra', p_medio => 'efectivo');
select registrar_gasto(p_origen => 'test', p_fecha => hoy()::text, p_monto => '-200', p_descripcion => 'Devolución', p_forma => 'tarjeta', p_tarjeta => 'Prueba',
  p_cuotas => '6', p_primer_mes => mes_actual());
select registrar_deuda(p_origen => 'test', p_fecha => '2026-10-02', p_persona => 'Persona D', p_concepto => 'x', p_monto => '10');
do $$
declare malos text[] := array['1.500', '1.234,56', '1500,50', '1e3', '12.345'];
        m text; f text;
begin
  assert (select count(*) from plata_gastos) = 3, 'no se cargaron los gastos válidos';
  assert (select valor from plata_dolar) = 1450.5;
  foreach m in array malos loop
    begin
      perform registrar_gasto(p_origen => 'test', p_fecha => '2026-10-19', p_monto => m, p_medio => 'efectivo');
      raise exception 'pasó el monto %', m;
    exception when raise_exception then
      if sqlerrm like 'pasó%' then raise; end if;
    end;
  end loop;
  foreach f in array array['02/11/2026', '2026-13-01', '2026-02-30', '2026-1-5'] loop
    begin
      perform registrar_gasto(p_origen => 'test', p_fecha => f, p_monto => '1', p_medio => 'efectivo');
      raise exception 'pasó la fecha %', f;
    exception when raise_exception then
      if sqlerrm like 'pasó%' then raise; end if;
    end;
  end loop;
  begin
    perform registrar_gasto(p_origen => 'test', p_fecha => '2026-10-19', p_monto => '1', p_forma => 'tarjeta', p_tarjeta => 'Prueba', p_cuotas => '3');
    raise exception 'pasó un gasto con tarjeta sin primer_mes';
  exception when raise_exception then
    if sqlerrm like 'pasó%' then raise; end if;
  end;
  assert (select count(*) from plata_gastos) = 3, 'algo inválido llegó a plata';
end $$;
