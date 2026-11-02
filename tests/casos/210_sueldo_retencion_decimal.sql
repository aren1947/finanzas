-- La retención '17,5%' se lee como 17 (num corta en la coma), y el neto queda mal.
insert into bronce_sueldo (origen, fecha_cobro_texto, bruto_texto, retencion_texto, neto_texto)
values ('test', '01/10/26', '1.000.000', '17,5%', '825.000');
select correr_etl();
do $$ begin
  assert (select bruto_ars from plata_sueldo) = 1000000, 'el bruto con puntos de miles no da 1.000.000';
  assert abs((select neto_ars from plata_sueldo) - 825000) < 0.01,
    format('neto %s en vez de 825000', (select neto_ars from plata_sueldo));
end $$;
