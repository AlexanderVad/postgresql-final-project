with managers_bonus as (
    select 
        project_manager_id,
        concat_ws(' ', last_name, first_name, middle_name) as full_name,
        0.01 * sum(project_cost) as bonus,
        rank() over (order by 0.01 * sum(project_cost) desc)
    from person p 
    join employee e on e.person_id = p.person_id 
    join project pj on pj.project_manager_id = e.employee_id 
    where status = 'Завершен'
    group by project_manager_id, p.person_id)
select full_name, project_manager_id, bonus
from managers_bonus
where rank = 1