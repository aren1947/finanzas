-- Dos compras distintas en cuotas, mismo comercio, monto y mes: oro_cuotas_proyectadas hace distinct y las junta en una.
insert into bronce_resumenes_lineas (origen, tarjeta, vencimiento, fecha_texto, referencia, cuota, comprobante, pesos_texto, dolares_texto)
values ('pdf', 'TARJ PRUEBA', to_char(hoy() + 5, 'DD/MM/YY'), to_char(hoy(), 'DD/MM/YY'), 'ZAPAS', '01/03', '1', '1.000,00', ''),
       ('pdf', 'TARJ PRUEBA', to_char(hoy() + 5, 'DD/MM/YY'), to_char(hoy() - 1, 'DD/MM/YY'), 'ZAPAS', '01/03', '2', '1.000,00', '');
select correr_etl();
do $$ begin
  assert (select sum(monto_ars) from oro_cuotas_proyectadas) = 6000,
    format('dos compras de 3 cuotas de 1000 proyectan %s', (select sum(monto_ars) from oro_cuotas_proyectadas));
end $$;
