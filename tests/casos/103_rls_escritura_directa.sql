-- La política es "for all" en plata y oro: la cuenta habilitada puede escribir directo en oro (salteando bronce y el ETL).
-- En oro_resumen_items esa fila además sobrevive al ETL, porque el MERGE se lee a sí mismo como fuente.
insert into _cuentas_habilitadas (mail, nombre) values ('habilitada@example.com', 'Prueba');
set role authenticated;
set request.jwt.claims = '{"email":"habilitada@example.com"}';
do $$ begin
  begin
    insert into oro_movimientos (origen_tabla, origen_id, fecha, tipo, categoria_id, descripcion, monto_ars)
    values ('a_mano', 1, '2026-10-01', 'gasto', 1, 'escrito directo en oro', 999);
  exception when insufficient_privilege then return; end;
  raise exception 'se pudo escribir directo en oro_movimientos desde la app';
end $$;
