-- Una línea de resumen con la cuota en formato corto ('1/3' en vez de '01/03') queda con cuota_total 0
-- y no proyecta ninguna cuota: la compra desaparece del detalle del resumen.
insert into bronce_resumenes_lineas (origen, tarjeta, vencimiento, fecha_texto, referencia, cuota, comprobante, pesos_texto, dolares_texto)
values ('pdf', 'TARJ PRUEBA', to_char(hoy() + 5, 'DD/MM/YY'), to_char(hoy(), 'DD/MM/YY'), 'TIENDA', '1/3', '9', '3.000,00', ''),
       ('pdf', 'TARJ PRUEBA', to_char(hoy() + 5, 'DD/MM/YY'), to_char(hoy(), 'DD/MM/YY'), 'OTRA', '01/03', '8', '2.000,00', '');
select correr_etl();
do $$ begin
  assert (select cuota_total from plata_lineas_tarjeta where referencia = 'TIENDA') = 3, 'cuota "1/3" no dio cuota_total 3';
  assert (select cuota_nro from plata_lineas_tarjeta where referencia = 'TIENDA') = 1, 'cuota "1/3" no dio cuota_nro 1';
  assert (select cuota_total from plata_lineas_tarjeta where referencia = 'OTRA') = 3, 'cuota "01/03" dejó de andar';
  assert (select count(*) from oro_cuotas_proyectadas) = 6, 'no se proyectan las 3 + 3 cuotas';
end $$;
