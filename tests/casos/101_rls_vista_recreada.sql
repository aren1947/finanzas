-- Volver a subir un archivo de vistas/ (create or replace view) borra security_invoker:
-- la vista pasa a correr como su dueño (postgres, que no pasa por RLS) y cualquier login de Google la lee.
insert into _cuentas_habilitadas (mail, nombre) values ('habilitada@example.com', 'Prueba');
select registrar_gasto(p_origen => 'test', p_fecha => '2026-10-01', p_monto => '1000', p_descripcion => 'Algo', p_medio => 'efectivo');
\i vistas/030_tablero_mes.sql
set role authenticated;
set request.jwt.claims = '{"email":"cualquiera@example.com"}';
do $$ begin
  assert (select count(*) from tablero_movimientos) = 0,
    format('después de re-subir vistas/030, un login no habilitado ve %s movimientos', (select count(*) from tablero_movimientos));
end $$;
