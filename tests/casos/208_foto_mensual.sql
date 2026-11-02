-- oro_foto_mensual resta las compras del resumen como "pendientes" aunque ya estén pagadas (y contadas en gastos_pagados).
insert into bronce_sueldo (origen, fecha_cobro_texto, bruto_texto, retencion_texto, neto_texto)
values ('test', to_char(hoy(), 'DD/MM/YY'), '100000', '0%', '100000');
insert into bronce_resumenes_lineas (origen, tarjeta, vencimiento, fecha_texto, referencia, cuota, comprobante, pesos_texto, dolares_texto)
values ('pdf', 'TARJ PRUEBA', to_char(hoy(), 'DD/MM/YY'), to_char(hoy() - 20, 'DD/MM/YY'), 'SUPER SA', '', '1', '10.000,00', '');
select correr_etl();
select registrar_pago(p_origen => 'test', p_fecha => hoy()::text, p_monto => '10000', p_tarjeta => 'Prueba', p_mes => mes_actual());
do $$ begin
  assert (select libre_despues_de_resumenes from oro_foto_mensual where periodo = mes_actual()) = 90000,
    format('ingresé 100000, pagué 10000 y la foto dice libre %s',
           (select libre_despues_de_resumenes from oro_foto_mensual where periodo = mes_actual()));
end $$;
