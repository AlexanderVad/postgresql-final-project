-- Задание 1
--Получите количество проектов, подписанных в 2023 году.
--В результат вывести одно значение количества

select count(*) 
from project p 
where date_part('year', sign_date) = 2023 

--Задание 2
--Получите общий возраст сотрудников, нанятых в 2022 году.
--Результат вывести одним значением в виде "... years ... months ... days"
--Использование более 2х функций для работы с типом данных дата и время будет являться ошибкой.

select 
	sum (age (current_date, birthdate))
from person p
join employee e on e.person_id = p.person_id
where date_part('year', hire_date) = 2022


--Задание 3
--Получите сотрудников, у которого фамилия начинается на М, всего в фамилии 8 букв и который работает дольше других.
--Если таких сотрудников несколько, выведите одного случайного.
--В результат выведите два столбца, в первом должны быть имя и фамилия через пробел, во втором дата найма.

select concat_ws(' ', last_name, first_name)as last_first_name, hire_date
from person p 
join employee e on e.person_id = p.person_id
where last_name like 'М_______' and dismissal_date is null 
order by hire_date 
limit 1

--Задание 4
--Получите среднее значение полных лет сотрудников, которые уволены и не задействованы на проектах.
--В результат вывести одно среднее значение. Если получаете null, то в результат нужно вывести 0.

select 
    coalesce(avg(date_part('year', age(current_date, p.birthdate))), 0.00) as avg_age_emp
from person p
join employee e on e.person_id = p.person_id
left join (
    select unnest(employees_id) as employees_id from project
    union all
    select project_manager_id from project
) p2 on p2.employees_id = e.employee_id
where dismissal_date is not null 
  and p2.employees_id is null

--Задание 5
--Чему равна сумма полученных платежей от контрагентов из Жуковский, Россия.
--В результат вывести одно значение суммы.

select sum(amount)
	from country c 
	join city c2 on c2.country_id = c.country_id 
	join address a on a.city_id = c2.city_id 
	join customer cu on cu.address_id = a.address_id 
	join project p on p.customer_id = cu.customer_id 
	join project_payment pp on pp.project_id = p.project_id 
where c.country_name = 'Россия' and city_name = 'Жуковский' and pp.fact_transaction_timestamp is not null


--Задание 6
--Пусть руководитель проекта получает премию в 1% от стоимости завершенных проектов.
--Если взять завершенные проекты, какой руководитель проекта получит самый большой бонус?
--В результат нужно вывести идентификатор руководителя проекта, его ФИО и размер бонуса.
--Если таких руководителей несколько, предусмотреть вывод всех.

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

--Задание7
--Получите накопительный итог планируемых авансовых платежей на каждый месяц в отдельности.
--Выведите в результат те даты планируемых платежей, которые идут после преодаления накопительной суммой значения в 30 000 000

with cte1 as(
	select plan_payment_date,
		amount,
		sum(amount) over (partition by date_part('year', plan_payment_date ), date_part('month', plan_payment_date) order by plan_payment_date) as cs
	from project_payment pp 
	where payment_type  = 'Авансовый'),
cte2 as (
	select *,
	row_number () over (partition by date_part('year', plan_payment_date ), date_part('month', plan_payment_date) order by plan_payment_date) as rn
	from cte1
	where cs > 30000000)
select plan_payment_date
from cte2
where rn = 1

--8. Используя рекурсию посчитайте сумму фактических окладов сотрудников из структурного подразделения с id равным 17 и всех дочерних подразделений.
--В результат вывести одно значение суммы.


with recursive departments as (
    select unit_id
    from "company_structure"
    where unit_id = 17

    union

    select child.unit_id
    from "company_structure" as child
    join departments as parent on child.parent_id = parent.unit_id
)
select sum(salary * rate) as total_salary
from departments as d
join "position" as p on p.unit_id = d.unit_id
join employee_position as ep on ep.position_id = p.position_id


--9. Задание выполняется одним запросом.
--Сделайте сквозную нумерацию фактических платежей по проектам на каждый год в отдельности в порядке даты платежей.
--Получите платежи, сквозной номер которых кратен 5.
--Выведите скользящее среднее размеров платежей с шагом 2 строки назад и 2 строки вперед от текущей.
--Получите сумму скользящих средних значений.
--Получите сумму стоимости проектов на каждый год.
--Выведите в результат значение года (годов) и сумму проектов, где сумма проектов меньше, чем сумма скользящих средних значений.

with row_n as (
	select 
		project_payment_id,
		amount,
		fact_transaction_timestamp,
		row_number() over (partition by date_part('year', fact_transaction_timestamp) order by fact_transaction_timestamp) as rn
	from project_payment pp
	where fact_transaction_timestamp is not null),
 row_nn as (
	select *
	from row_n
	where rn % 5 = 0),
row_avg as (
	select *,
	avg (amount) over (order by fact_transaction_timestamp rows between 2 preceding and 2 following) as mav
	from row_nn),
sum_row_avg as (
	select sum (mav) as total_mav
	from row_avg),
projects_cost as (
    select
        date_part('year', sign_date) as project_year,
        sum(project_cost) as project_cost
    from project p
    group by date_part('year', sign_date))
select project_year, project_cost
from projects_cost
where project_cost < (select total_mav from sum_row_avg)

--10. Создайте материализованное представление, которое будет хранить отчет следующей структуры:
--идентификатор проекта
--название проекта
--дата последней фактической оплаты по проекту
--размер последней фактической оплаты
--ФИО руководителей проектов
--Названия контрагентов
--В виде строки названия типов работ по каждому контрагенту

create materialized view task10 as
with last_payments as (
    select 
        project_id,
        fact_transaction_timestamp,
        amount,
        row_number() over (partition by project_id order by fact_transaction_timestamp desc) as rn
    from project_payment
    where fact_transaction_timestamp is not null),
types_of_work as (
	select	
		c.customer_id,
		c.customer_name, 
		string_agg(tw.type_of_work_name, ', ') as types_of_work_name
	from customer c 
	join customer_type_of_work ctow on c.customer_id = ctow.customer_id
	join type_of_work tw on tw.type_of_work_id = ctow.type_of_work_id
	group by c.customer_id)
select
	lp.project_id,
	p.project_name,
	lp.fact_transaction_timestamp,
	lp.amount, 
	concat_ws(' ', last_name, first_name, middle_name) as full_name,
	tow.customer_name,
	types_of_work_name
from project p 
join employee e on e.employee_id = p.project_manager_id 
join person pe on pe.person_id = e.person_id 
join last_payments lp on lp.project_id = p.project_id 
join types_of_work tow on tow.customer_id = p.customer_id 
where rn = 1