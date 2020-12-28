do $$
BEGIN
  IF EXISTS ( SELECT  1 FROM Information_Schema.Routines WHERE  Routine_Type ='FUNCTION' AND routine_name = 'get_json_attrs' ) THEN
    DROP FUNCTION public.get_json_attrs;
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.get_json_attrs(
  target jsonb,
  update_attributes jsonb)
    RETURNS json
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS $BODY$

DECLARE
   _key text;
   temp jsonb;
   ignore_for_copy text [] := array['id', 'created_at', 'updated_at', 'valid_from', 'valid_till'];
begin
    ignore_for_copy := ignore_for_copy || ARRAY(SELECT jsonb_object_keys(update_attributes));
    temp := target;
    FOREACH _key IN ARRAY ignore_for_copy LOOP
      temp := temp - _key;
    END LOOP;

    RETURN temp || update_attributes;
end

$BODY$;
