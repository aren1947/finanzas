# Finanzas de Aren

Las finanzas de Tomás en Postgres (Supabase): un almacén **bronce → plata → oro** que arma Aren, el asistente de Tomás.
Este repo es **solo código**: los datos viven en Supabase, nunca acá.

| Carpeta | Qué hay |
|---|---|
| `esquema/` | Ayudantes (fechas en hora argentina, números de texto), tablas por capa, validaciones y el corredor del ETL. Se aplica una vez, al crear la base |
| `etl/` | **El ETL, en orden de nombre.** Cada archivo es un `MERGE` que arma una tabla de plata u oro desde la capa de abajo: inserta lo nuevo, actualiza lo que cambió (sin cambiar ids) y borra lo que ya no sale. El encabezado dice qué lee y cuál es su clave |
| `vistas/` | Lo que se consulta: `oro_*` y `tablero_*` (resumen del mes, presupuestos, deudas, ahorro…) |
| `procedimientos/` | Las cargas (`registrar_gasto`, `registrar_compartido`, `pagar_deuda`…): escriben solo en bronce y corren el ETL en la misma transacción |

## Cómo se usa

Aren lo maneja con `aren-supabase` en su server:

```sh
aren-supabase ejecutar registrar_gasto origen=mensaje fecha=2026-10-19 monto=1000 descripcion=Precintos medio=efectivo
aren-supabase sql "select * from tablero_resumen"
aren-supabase etl                                   # corre el ETL y dice qué hizo en cada tabla
aren-supabase subir ~/apps/finanzas etl             # después de cambiar un archivo de etl/
```

Si editás un archivo de `etl/`, `vistas/` o `procedimientos/`, subilo (o pedíselo a Aren) con `aren-supabase subir`.
Un cambio de tablas va como SQL aparte (`alter table …`) y después se refleja en `esquema/`.
