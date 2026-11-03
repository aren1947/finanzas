-- Un login no habilitado que llama a correr_etl() no ve las filas, así que tampoco puede borrarlas.
insert into _cuentas_habilitadas (mail, nombre) values ('habilitada@example.com', 'Prueba');
select registrar_gasto(p_origen => 'test', p_fecha => '2026-10-01', p_monto => '1000', p_descripcion => 'Algo', p_medio => 'efectivo');
set role authenticated;
set request.jwt.claims = '{"email":"cualquiera@example.com"}';
select * from correr_etl();
do $$ begin
  begin
    perform registrar_gasto(p_origen => 'intruso', p_fecha => '2026-10-01', p_monto => '1', p_medio => 'efectivo');
    raise exception 'un login no habilitado pudo cargar un gasto';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
  assert (select count(*) from plata_gastos) = 1, 'el ETL de un no habilitado borró filas';
  assert (select count(*) from oro_movimientos) = 1, 'el ETL de un no habilitado borró movimientos';
end $$;
