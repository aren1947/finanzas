-- Validaciones de lo que entra a bronce: cortan la carga con un mensaje claro (lo lee Aren y se lo dice a Tomás).

create or replace function valida_categoria_egreso(cat text) returns void language plpgsql as $$
begin
  if not exists (select 1 from dim_categoria where nombre = cat and tipo = 'egreso') then
    raise exception 'no existe esa categoría de gasto: creala antes con crear_categoria';
  end if;
end $$;

create or replace function bronce_presupuestos_valida() returns trigger language plpgsql as $$
begin
  perform valida_categoria_egreso(new.categoria);
  return new;
end $$;
create trigger bronce_presupuestos_valida before insert on bronce_presupuestos
  for each row execute function bronce_presupuestos_valida();

create or replace function bronce_compartidos_valida() returns trigger language plpgsql as $$
begin
  perform valida_categoria_egreso(new.categoria);
  if not exists (select 1 from dim_medio where nombre = new.medio and nombre <> 'tarjeta') then
    raise exception 'medio: debito, efectivo o transferencia (con tarjeta todavía no: cargalo como gasto y la parte del otro como deuda)';
  end if;
  return new;
end $$;
create trigger bronce_compartidos_valida before insert on bronce_compartidos
  for each row execute function bronce_compartidos_valida();

create or replace function bronce_previstos_valida() returns trigger language plpgsql as $$
begin
  if new.periodo < mes_actual() then
    raise exception 'ese mes ya pasó: un previsto es para este mes o los que vienen';
  end if;
  if new.categoria is not null then
    perform valida_categoria_egreso(new.categoria);
  end if;
  return new;
end $$;
create trigger bronce_previstos_valida before insert on bronce_previstos
  for each row execute function bronce_previstos_valida();

create or replace function bronce_previstos_cambios_valida() returns trigger language plpgsql as $$
begin
  if not exists (select 1 from bronce_previstos where id = new.previsto_id)
     or exists (select 1 from bronce_previstos_cambios where previsto_id = new.previsto_id and accion in ('confirmar', 'descartar'))
     or (new.periodo is not null and new.periodo < mes_actual()) then
    raise exception 'ese previsto no existe, ya está confirmado o descartado, o el mes ya pasó';
  end if;
  return new;
end $$;
create trigger bronce_previstos_cambios_valida before insert on bronce_previstos_cambios
  for each row execute function bronce_previstos_cambios_valida();

create or replace function bronce_ahorro_metas_valida() returns trigger language plpgsql as $$
begin
  if new.monto > 0 and (new.para < mes_actual() or new.para > mes_mas(mes_actual(), 24)) then
    raise exception 'ese mes ya pasó, o está a más de dos años';
  end if;
  return new;
end $$;
create trigger bronce_ahorro_metas_valida before insert on bronce_ahorro_metas
  for each row execute function bronce_ahorro_metas_valida();

create or replace function bronce_compensaciones_valida() returns trigger language plpgsql as $$
begin
  if (select count(*) from plata_deudas where id in (new.deuda_id, new.contra_deuda_id)) < 2 then
    raise exception 'no existe alguna de las dos deudas';
  end if;
  if (select count(distinct persona_id) from plata_deudas where id in (new.deuda_id, new.contra_deuda_id)) <> 1
     or (select count(distinct sentido) from plata_deudas where id in (new.deuda_id, new.contra_deuda_id)) <> 2 then
    raise exception 'las dos deudas tienen que ser con la misma persona y en sentidos opuestos (una te deben, otra debés)';
  end if;
  if new.monto is null or new.monto <= 0 then
    raise exception 'no hay nada para compensar: alguna de las dos deudas ya está saldada';
  end if;
  return new;
end $$;
create trigger bronce_compensaciones_valida before insert on bronce_compensaciones
  for each row execute function bronce_compensaciones_valida();
