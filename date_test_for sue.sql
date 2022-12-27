select OFFENDER_ID, CHARGE_ID, 

       to_Date(decode(c.status_end_date,null,null,to_char(c.STATUS_END_DATE, 'mm/dd/yyyy')||' 23:59:59')) as new_end,

       STATUS_END_DATE as org_col_end,

       to_Date(decode(c.status_start_date,null,null,to_char(c.STATUS_start_DATE, 'mm/dd/yyyy')||' 00:00:00'))  as new_start,

       STATUS_START_DATE as org_col_start,

		CEIL(to_Date(decode(c.status_end_date,null,null,to_char(c.STATUS_END_DATE, 'mm/dd/yyyy')||' 23:59:59'))-
       		to_Date(decode(c.status_start_date,null,null,to_char(c.STATUS_start_DATE, 'mm/dd/yyyy')||' 00:00:00'))) as new_calc_of_days_in_2,

       c.OFFTRK_DAYS_IN as org_off_days_in, DAYS_IN as org_days_in
from CHARGES c
where c.status_end_date is not null;