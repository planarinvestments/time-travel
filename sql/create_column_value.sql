do $$
BEGIN
  IF EXISTS ( SELECT  1 FROM Information_Schema.Routines WHERE  Routine_Type ='FUNCTION' AND routine_name = 'create_column_value' ) THEN
    DROP FUNCTION public.create_column_value;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.create_column_value(
  target json,
  time_current timestamp,
  table_name text,
  update_attributes json,
  infinite_date timestamp
  )
    RETURNS bigint
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS $BODY$

DECLARE
  _columns text;
  _values text;
  _key text;
  _value text;
  c bigint;
  ignore_for_copy text [] := array['id', 'created_at', 'updated_at', 'valid_from', 'valid_till'];
  update_columns text[] ;
begin
  IF target ->> 'effective_from' = target ->> 'effective_till' THEN
    return null;
  ELSE
    FOR _key, _value IN SELECT * FROM json_each(update_attributes) LOOP
      update_columns := update_columns  || _key ;
    END LOOP;

    FOR _key, _value IN SELECT * FROM json_each(target) LOOP
      IF _key = ANY(ignore_for_copy || update_columns) THEN
      ELSE
        _columns := concat(_columns, quote_ident(_key), ',');
        _values := concat(_values,  _value, ',');
      END IF;
    END LOOP;

    FOR _key, _value IN SELECT * FROM json_each(update_attributes) LOOP
      IF _key = ANY(ignore_for_copy) THEN
      ELSE
        _columns := concat(_columns, quote_ident(_key), ',');
        _values := concat(_values,  _value, ',');
      END IF;
    END LOOP;

    _columns := concat('(',_columns, 'valid_from,', 'valid_till', ')');
    _values := concat('(',_values, '"', time_current, '","', infinite_date, '")');
    _values := replace(_values, Chr(34), Chr(39));
    -- RAISE NOTICE 'insert statement %', concat('INSERT INTO ', table_name, ' ', _columns, ' VALUES ', _values , 'RETURNING id') ;
    EXECUTE concat('INSERT INTO ', table_name, ' ', _columns, ' VALUES ', _values , 'RETURNING id') INTO c;
    return c;
  END IF;
end

$BODY$;
