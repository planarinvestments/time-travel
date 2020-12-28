do $$
BEGIN
  IF EXISTS ( SELECT  1 FROM Information_Schema.Routines WHERE  Routine_Type ='FUNCTION' AND routine_name = 'update_latest') THEN
    DROP FUNCTION public.update_latest;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.update_latest(
  query text,
  table_name text,
  update_attrs text,
  empty_obj_attrs text,
  effective_from timestamp,
  effective_till timestamp,
  time_current timestamp,
  infinite_date timestamp
  )

  RETURNS void
  LANGUAGE 'plpgsql'

  COST 100
  VOLATILE
AS $BODY$

DECLARE
   affected_rows bigint[];
   target RECORD;
   current_record RECORD;
   res jsonb;
   current_id bigint;
   -- original_effective_till timestamp;
   -- original_effective_from timestamp;
   update_attrs_json jsonb;
   empty_obj_attrs_json jsonb;
   -- head_found boolean;
   -- tail_found boolean;
   timeframe_attrs jsonb[] := '{}';
   timeframe jsonb;
   -- previous_timeframe jsonb;
   -- temp_prev jsonb;
   -- temp_curr jsonb;
begin
  update_attrs_json := update_attrs::jsonb;
  empty_obj_attrs_json := empty_obj_attrs::jsonb;

  -- HEAD START
  -- RAISE NOTICE 'head start';
  FOR target IN EXECUTE concat(query, ' AND effective_from <= $1 AND effective_till = $2  order by effective_from ASC limit 1') USING effective_from, infinite_date LOOP
    -- RAISE NOTICE 'inside head iteration';
    -- head_found := true;
    -- original_effective_till := target.effective_till;
    -- original_effective_from := target.effective_from;

    -- HEAD NON-OVERLAPPING (with new) TIMEFRAME
    IF target.effective_from <> effective_from THEN
      target.effective_till := effective_from;
      select get_json_attrs(to_jsonb(target), '{}'::jsonb) into res ;
      timeframe_attrs := timeframe_attrs || res;
      -- RAISE NOTICE 'new ineffective head id %',jsonb_pretty(res);
    END IF;

    -- HEAD AND NEW OVERLAPPING TIMEFRAME
    target.effective_from := effective_from;
    target.effective_till := effective_till;
    select get_json_attrs(to_jsonb(target), update_attrs_json) into res ;
    timeframe_attrs := timeframe_attrs || res;

    EXECUTE 'UPDATE ' || table_name||  ' SET valid_till=$1 WHERE id=$2' USING time_current, target.id;
  END LOOP;

  -- HANGING ANYWHERE
  IF array_length(timeframe_attrs, 1) IS NULL THEN
    EXECUTE(concat(query, ' LIMIT 1')) INTO current_record;
    IF current_record IS NULL THEN
      res := jsonb_build_object('effective_from', effective_from) || jsonb_build_object('effective_till', effective_till);
      select get_json_attrs(empty_obj_attrs_json, update_attrs_json || res) into res ;
      timeframe_attrs := timeframe_attrs || res;
    ELSE
      RAISE EXCEPTION 'you cannot update non latest values';
    END IF;
    -- RAISE NOTICE 'hanging %', jsonb_pretty(res);
  END IF;

  FOREACH timeframe IN ARRAY timeframe_attrs LOOP
    select create_column_value(to_json(timeframe), time_current, table_name, '{}'::json, infinite_date) INTO current_id;
  END LOOP;
end

$BODY$;
