do $$
DECLARE
  routine_record text;
BEGIN
  IF EXISTS ( SELECT  1 FROM Information_Schema.Routines WHERE  Routine_Type ='FUNCTION' AND routine_name = 'update_bulk_history') THEN
    SELECT CONCAT(routine_schema, '.', routine_name) INTO routine_record FROM Information_Schema.Routines WHERE  Routine_Type ='FUNCTION' AND routine_name = 'update_bulk_history' limit 1;
    EXECUTE concat('DROP FUNCTION ', routine_record);
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION update_bulk_history(
  query text,
  table_name text,
  update_attrs text,
  latest_transactions boolean
  )

  RETURNS void
  LANGUAGE 'plpgsql'

  COST 100
  VOLATILE
AS $BODY$

DECLARE
  record_values json;
  record  text[];
  new_query text;
  new_timeline_clauses text;
  new_update_arr text[];
  effective_from text;
  effective_till text;
  time_current text;
  infinite_date text;
  timeline_clauses text;
  empty_obj_attrs text;
  _key text;
  _value text;
begin

  FOREACH record_values IN ARRAY(SELECT ARRAY(SELECT json_array_elements(update_attrs::json))) LOOP

    update_attrs := (record_values->'update_attrs');
    timeline_clauses := (record_values->'timeline_clauses');
    empty_obj_attrs := (record_values->'empty_obj_attrs');

    effective_from := (record_values->'effective_from');
    effective_till := (record_values->'effective_till');
    time_current := (record_values->'current_time');
    infinite_date := (record_values->'infinite_date');

    new_query := query;

    -- build query with timeline clauses
    FOR _key, _value IN SELECT * FROM json_each(timeline_clauses::json) LOOP
      new_query := concat(new_query, ' AND "', table_name, '"."', _key, '" = ', REPLACE(_value, '"', ''''));
    END LOOP;

    IF latest_transactions THEN
      PERFORM update_latest (new_query, table_name, update_attrs, empty_obj_attrs, effective_from::timestamp, effective_till::timestamp, time_current::timestamp, infinite_date::timestamp);
    ELSE
      PERFORM update_history (new_query, table_name, update_attrs, empty_obj_attrs, effective_from::timestamp, effective_till::timestamp, time_current::timestamp, infinite_date::timestamp);
    END IF;
  END LOOP;
end

$BODY$;
