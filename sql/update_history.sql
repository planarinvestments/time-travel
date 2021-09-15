do $$
DECLARE
  routine_record text;
BEGIN
  IF EXISTS ( SELECT  1 FROM Information_Schema.Routines WHERE  Routine_Type ='FUNCTION' AND routine_name = 'update_history') THEN
    SELECT CONCAT(routine_schema, '.', routine_name) INTO routine_record FROM Information_Schema.Routines WHERE  Routine_Type ='FUNCTION' AND routine_name = 'update_history' limit 1;
    EXECUTE concat('DROP FUNCTION ', routine_record);
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION update_history(
  query text,
  table_name text,
  update_attrs text,
  empty_obj_attrs text,
  effective_from timestamp,
  effective_till timestamp,
  time_current timestamp,
  infinite_date timestamp
  )

  RETURNS bigint[]
  LANGUAGE 'plpgsql'

  COST 100
  VOLATILE
AS $BODY$

DECLARE
   affected_rows bigint[];
   target RECORD;
   pre_post RECORD;
   res jsonb;
   current_id bigint;
   in_between_effective_till timestamp;
   original_effective_till timestamp;
   original_effective_from timestamp;
   update_attrs_json jsonb;
   empty_obj_attrs_json jsonb;
   head_found boolean;
   tail_found boolean;
   timeframe_attrs jsonb[] := '{}';
   timeframe jsonb;
   previous_timeframe jsonb;
   temp_prev jsonb;
   temp_curr jsonb;
begin
  update_attrs_json := update_attrs::jsonb;
  empty_obj_attrs_json := empty_obj_attrs::jsonb;

  -- HEAD START
  -- RAISE NOTICE 'head start';
  FOR target IN EXECUTE concat(query, ' AND effective_from <= $1 AND effective_till > $2 order by effective_from ASC limit 1') USING effective_from, effective_from LOOP
    -- RAISE NOTICE 'inside head iteration';
    head_found := true;
    original_effective_till := target.effective_till;
    original_effective_from := target.effective_from;

    -- HEAD NON-OVERLAPPING (with new) TIMEFRAME
    IF target.effective_from <> effective_from THEN
      target.effective_till := effective_from;
      select get_json_attrs(to_jsonb(target), '{}'::jsonb) into res ;
      timeframe_attrs := timeframe_attrs || res;
      -- RAISE NOTICE 'new ineffective head id %',jsonb_pretty(res);
    END IF;

    -- HEAD AND NEW OVERLAPPING TIMEFRAME
    target.effective_from := effective_from;
    IF original_effective_till > effective_till THEN
      target.effective_till := effective_till;
    ELSE
      target.effective_till := original_effective_till;
    END IF;
    select get_json_attrs(to_jsonb(target), update_attrs_json) into res ;
    timeframe_attrs := timeframe_attrs || res;
    -- RAISE NOTICE 'new in head  id %', jsonb_pretty(res);

    -- HEAD TAIL SAME, TAIL NON-OVERLAPPING (with new) TIMEFRAME
    IF original_effective_from < effective_till AND original_effective_till > effective_till THEN
      -- RAISE NOTICE 'same record head and tail';
      target.effective_from := effective_till;
      target.effective_till := original_effective_till;
      select get_json_attrs(to_jsonb(target), '{}'::jsonb) into res ;
      timeframe_attrs := timeframe_attrs || res;
      -- RAISE NOTICE 'new tail id %', jsonb_pretty(res);
    END IF;

    -- NO TAIL, NEW NON-OVERLAPPING (with head) TIMEFRAME
    EXECUTE concat(query, ' AND effective_till >= $1 limit 1') USING effective_till INTO pre_post;
    -- RAISE NOTICE 'extending future pre post %', pre_post;
    IF pre_post.effective_from IS NULL THEN
      -- RAISE NOTICE 'extending future';
      target.effective_from = original_effective_till;
      target.effective_till = effective_till;
      res = jsonb_build_object('effective_from', original_effective_till) || jsonb_build_object('effective_till', effective_till);
      select get_json_attrs(empty_obj_attrs_json, update_attrs_json || res) into res ;
      timeframe_attrs := timeframe_attrs || res;
      -- RAISE NOTICE 'future in head %', jsonb_pretty(res);
    END IF;

    EXECUTE 'UPDATE ' || table_name||  ' SET valid_till=$1 WHERE id=$2' USING time_current, target.id;
  END LOOP;

  -- NO HEAD, NEW NON OVERLAPPING(with any) TIMEFRAME
  -- HANGING IN PRE HISTORY
  IF head_found IS NULL THEN
    FOR target IN EXECUTE concat(query, ' AND effective_from > $1 order by effective_from ASC limit 1') USING effective_from LOOP
      IF target.effective_from > effective_till THEN -- hanging
        -- RAISE NOTICE 'hanging';
        res = jsonb_build_object('effective_from', effective_from) || jsonb_build_object('effective_till', effective_till);
      ELSE -- prehistoric
        -- RAISE NOTICE 'pre historic';
        res = jsonb_build_object('effective_from', effective_from) || jsonb_build_object('effective_till', target.effective_from);
      END IF;
      select get_json_attrs(empty_obj_attrs_json, update_attrs_json || res  ) into res ;
      timeframe_attrs := timeframe_attrs || res;
      -- RAISE NOTICE 'pre historic/hanging tail %', jsonb_pretty(res);
    END LOOP;
  END IF;

  -- BETWEEN AND NEW OVERLAPPING TIMEFRAME
  -- RAISE NOTICE 'between start';
  FOR target IN EXECUTE concat(query, ' AND effective_from > $1 AND effective_till < $2 order by effective_from ASC') USING effective_from, effective_till LOOP
    -- RAISE NOTICE ' inside between';
    select get_json_attrs(to_jsonb(target), update_attrs_json) into res ;
    timeframe_attrs := timeframe_attrs || res;

    in_between_effective_till := target.effective_till;
    -- RAISE NOTICE 'between %', jsonb_pretty(res);
    EXECUTE 'UPDATE ' || table_name||  ' SET valid_till=$1 WHERE id=$2' USING time_current, target.id;
  END LOOP;


  -- RAISE NOTICE 'tail start';
  FOR target IN EXECUTE concat(query, ' AND effective_from > $1 AND effective_from < $2 AND effective_till >= $3 order by effective_from ASC  limit 1') USING effective_from, effective_till, effective_till LOOP
    -- RAISE NOTICE 'inside tail iteration';
    -- TAIL AND NEW OVERLAPPING TIMEFRAME
    original_effective_from := target.effective_from;
    original_effective_till := target.effective_till;

    tail_found := true;
    target.effective_till := effective_till ;
    target.effective_from := original_effective_from;
    select get_json_attrs(to_jsonb(target), update_attrs_json) into res ;
    timeframe_attrs := timeframe_attrs || res;
    -- RAISE NOTICE 'new in tail id %', jsonb_pretty(res);

    -- TAIL NON-OVERLAPPING(with new) TIMEFRAME
    IF original_effective_till <> effective_till THEN
      target.effective_from := effective_till;
      target.effective_till := original_effective_till;
      select get_json_attrs(to_jsonb(target), '{}'::jsonb) into res ;
      timeframe_attrs := timeframe_attrs || res;
      -- RAISE NOTICE 'new ineffective tail id %', jsonb_pretty(res);
    END IF;
    EXECUTE 'UPDATE ' || table_name||  ' SET valid_till=$1 WHERE id=$2' USING time_current, target.id;
  END LOOP;

  -- ONLY BETWEEN AND NO TAIL, NEW NON-OVERLAPPING TIMEFRAME
  IF in_between_effective_till IS NOT NULL AND tail_found IS NULL THEN
    -- RAISE NOTICE 'in between with no tail';
    res := jsonb_build_object('effective_from', in_between_effective_till) || jsonb_build_object('effective_till', effective_till);
    select get_json_attrs(empty_obj_attrs_json, update_attrs_json || res) into res ;
    timeframe_attrs := timeframe_attrs || res;
    -- RAISE NOTICE 'in between with no tail %', jsonb_pretty(res);
  END IF;


  -- HANGING ANYWHERE
  IF array_length(timeframe_attrs, 1) IS NULL THEN
    res := jsonb_build_object('effective_from', effective_from) || jsonb_build_object('effective_till', effective_till);
    select get_json_attrs(empty_obj_attrs_json, update_attrs_json || res) into res ;
    timeframe_attrs := timeframe_attrs || res;
    -- RAISE NOTICE 'hanging %', jsonb_pretty(res);
  END IF;


  -- SQUISH RECORDS
  previous_timeframe := null;

  FOREACH timeframe IN ARRAY timeframe_attrs LOOP
    IF previous_timeframe IS NOT NULL THEN
      temp_prev = previous_timeframe - 'effective_from' - 'effective_till';
      temp_curr = timeframe - 'effective_from' - 'effective_till';

      IF previous_timeframe -> 'effective_till' < timeframe -> 'effective_from' THEN
        previous_timeframe := previous_timeframe || jsonb_build_object('effective_till', timeframe -> 'effective_from');
      END IF;

      IF temp_prev @> temp_curr AND temp_prev <@ temp_curr THEN
        previous_timeframe := previous_timeframe || jsonb_build_object('effective_till',timeframe -> 'effective_till');
      ELSE
        select create_column_value(to_json(previous_timeframe), time_current, table_name, '{}'::json, infinite_date) INTO current_id;
        previous_timeframe := timeframe;
      END IF;
    ELSE
      previous_timeframe := timeframe;
    END IF;
  END LOOP;

  IF previous_timeframe IS NOT NULL THEN
    select create_column_value(to_json(previous_timeframe), time_current, table_name, '{}'::json, infinite_date) INTO current_id;
  END IF;

  return affected_rows;
end

$BODY$;
