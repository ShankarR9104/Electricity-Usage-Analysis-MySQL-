create database project;
use project;

show tables;
select * from appliance_usage;
select * from billing_info;
select * from calculated_metrics;
select * from environmental_data;
select * from household_info;

alter table appliance_usage modify household_id varchar(10) not null;
alter table appliance_usage add primary key (household_id);

alter table billing_info modify household_id varchar(10) not null;
alter table billing_info add primary key (household_id);

alter table calculated_metrics modify household_id varchar(10) not null;
alter table calculated_metrics add primary key (household_id);

alter table environmental_data modify household_id varchar(10) not null;
alter table environmental_data add primary key (household_id);

alter table household_info modify household_id varchar(10) not null;
alter table household_info add primary key (household_id);

describe appliance_usage;
describe billing_info;
describe calculated_metrics;
describe environmental_data;
describe household_info;

-- PROJECT TASK 1 

select household_id,cost_usd,
case 
	when cost_usd > 200 then 'High'
	when cost_usd < 100 then 'Low'
	else 'Medium'
end as new_payment_status from billing_info;

update billing_info set payment_status = 
case
	when cost_usd > 200 then 'High'
	when cost_usd < 100 then 'Low'
	else 'Medium'
end;

select * from billing_info;


-- PROJECT TASK 2

select household_id, year, month, sum(total_kwh) as monthly_total_kwh,
rank() over (
	partition by year
	order by sum(total_kwh) desc
) as usage_rank_in_year,
case
	when sum(total_kwh) > 500 then 'high'
	else 'low'
end as usage_level from billing_info group by household_id, year, month order by year, usage_rank_in_year;


-- PROJECT TASK 3

select household_id,
    sum(case when month = 'Jan' then total_kwh else 0 end) as january_usage,
    sum(case when month = 'Feb' then total_kwh else 0 end) as february_usage,
    sum(case when month = 'Mar' then total_kwh else 0 end) as march_usage
from billing_info group by household_id order by household_id;


-- PROJECT TASK 4

select h.household_id, h.city, round(avg(m.monthly_total_kwh), 2) as avg_monthly_kwh from 
( select household_id, year, month, sum(total_kwh) as monthly_total_kwh from billing_info group by household_id, year, month ) as m
join household_info h on m.household_id = h.household_id
group by h.household_id, h.city;


-- PROJECT TASK 5

select a.household_id, a.kwh_usage_ac, e.avg_outdoor_temp from appliance_usage a join environmental_data e on a.household_id = e.household_id
where a.household_id in ( select household_id from appliance_usage where kwh_usage_ac > 100);


-- PROJECT TASK 6

delimiter //
create procedure get_billing_info_by_region (in p_region text)
begin
select h.household_id, h.region, h.city, b.month, b.year, b.total_kwh, b.rate_per_kwh,
        cast(b.cost_usd as double) as cost_usd, b.payment_status
from household_info h join billing_info b on h.household_id = b.household_id where h.region = p_region;
end //
delimiter ;

call get_billing_info_by_region('north');


-- PROJECT TASK 7

delimiter //
create procedure get_total_usage (inout p_household_id varchar(10), inout p_total_usage double)
begin
select (kwh_usage_fridge + kwh_usage_heater + kwh_usage_ac + kwh_usage_washer + kwh_usage_dryer + kwh_usage_oven + kwh_usage_microwave + kwh_usage_tv + kwh_usage_computer + kwh_usage_lighting )
into p_total_usage from appliance_usage where household_id = p_household_id;
end //
delimiter ;

set @hid = 'H0001';
set @total = 0;
call get_total_usage(@hid, @total);

select @hid as household_id, @total as total_usage_kwh;


-- PROJECT TASK 8

delimiter //
create trigger before_insert_billing before insert on billing_info for each row
begin
set new.cost_usd = new.total_kwh * new.rate_per_kwh;
end //
delimiter ;

select household_id, total_kwh, rate_per_kwh, cost_usd from billing_info where household_id = 'H0003';


-- PROJECT TASK 9

delimiter //
create trigger after_insert_billing_metrics after insert on billing_info for each row
begin
declare v_num_occupants int;
declare v_kwh_per_occupant double;
declare v_usage_category varchar(20);
-- get number of occupants from household_info
select num_occupants into v_num_occupants from household_info where household_id = new.household_id;
-- calculate kwh per occupant
set v_kwh_per_occupant = new.total_kwh / v_num_occupants;
-- determine usage category
if new.total_kwh > 600 then
	set v_usage_category = 'High';
else
	set v_usage_category = 'Moderate';
end if;
-- insert calculated metrics
insert into calculated_metrices(household_id, kwh_per_occupant, usage_category)
values(new.household_id, v_kwh_per_occupant, v_usage_category);
end //
delimiter ;

select * from calculated_metrics where household_id = 'H0004';

-------------------- END -----------------------