-- RLS recién aplicado: anon no ve nada, un Google cualquiera ve 0 filas, la cuenta habilitada ve todo.
insert into _cuentas_habilitadas (mail, nombre) values ('habilitada@example.com', 'Prueba');
select registrar_gasto(p_origen => 'test', p_fecha => '2026-10-01', p_monto => '1000', p_descripcion => 'Algo', p_medio => 'efectivo');

set role anon;
do $$ begin
  perform 1 from tablero_movimientos;
  raise exception 'anon pudo leer tablero_movimientos';
exception when insufficient_privilege then null; end $$;
reset role;

set role authenticated;
set request.jwt.claims = '{"email":"cualquiera@example.com"}';
do $$ begin
  assert (select count(*) from tablero_movimientos) = 0, 'un login no habilitado ve movimientos';
  assert (select count(*) from plata_gastos) = 0, 'un login no habilitado ve plata_gastos';
end $$;
set request.jwt.claims = '{"email":"Habilitada@Example.com"}';
do $$ begin
  assert (select count(*) from tablero_movimientos) = 1, 'la cuenta habilitada no ve su movimiento';
end $$;
