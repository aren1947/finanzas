-- Cargar dos veces las mismas líneas de un resumen (mismo comprobante, fecha y monto) duplica las compras: no hay control.
insert into bronce_resumenes_lineas (origen, tarjeta, vencimiento, fecha_texto, referencia, cuota, comprobante, pesos_texto, dolares_texto)
select 'pdf', 'TARJ PRUEBA', to_char(hoy() + 5, 'DD/MM/YY'), to_char(hoy(), 'DD/MM/YY'), 'SUPER SA', '', '123', '1.000,00', ''
from generate_series(1, 2);
select correr_etl();
do $$ begin
  assert (select sum(monto) from oro_resumenes_detalle where origen = 'linea') = 1000,
    format('el resumen dice %s por una compra de 1000', (select sum(monto) from oro_resumenes_detalle where origen = 'linea'));
end $$;
