-- Catálogos inventados para las pruebas (nada de esto es real).
insert into dim_categoria (nombre, emoji, tipo) values
  ('Otros', '📦', 'egreso'), ('Super', '🛒', 'egreso'), ('Salidas', '🍻', 'egreso'), ('Sueldo', '💰', 'ingreso');
insert into dim_medio (nombre) values ('debito'), ('efectivo'), ('transferencia'), ('tarjeta'), ('compartido');
insert into dim_banco (nombre) values ('Banco Prueba');
insert into dim_tarjeta (nombre, banco_id, cierre_dia, vence_dia, nombre_visible) values ('TARJ PRUEBA', 1, 25, 5, 'Prueba');
