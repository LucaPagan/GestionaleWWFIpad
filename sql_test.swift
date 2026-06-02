let sql = """
CREATE OR REPLACE FUNCTION public.sync_path_steps(p_path_id uuid, p_steps jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_step jsonb;
  v_step_count integer;
begin
  -- ... validation
  delete from public.path_steps where path_id = p_path_id;
  for v_step in select * from jsonb_array_elements(coalesce(p_steps, '[]'::jsonb)) loop
    insert into public.path_steps (
      id, path_id, poi_id, step_order, direction_hint, distance_meters,
      estimated_minutes, path_geometry
    )
    values (
      coalesce(nullif(v_step->>'id', '')::uuid, extensions.uuid_generate_v4()),
      p_path_id,
      (v_step->>'poi_id')::uuid,
      (v_step->>'step_order')::integer,
      coalesce(v_step->>'direction_hint', ''),
      greatest(coalesce(nullif(v_step->>'distance_meters', '')::integer, 1), 1),
      greatest(coalesce(nullif(v_step->>'estimated_minutes', '')::integer, 1), 1),
      nullif(v_step->>'path_geometry', '')
    );
  end loop;
end;
$function$
"""
print(sql)
