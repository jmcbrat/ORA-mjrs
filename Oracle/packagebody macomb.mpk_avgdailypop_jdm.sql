CREATE OR REPLACE
PACKAGE BODY        mpk_avgdailypop_jdm
IS
 

cs_mod				constant varchar2(255) := 'DA';
gv_debug			boolean := false; --set to true to turn on logging

v_writ				EPIC.epic_locations.location_id%type;

v_dailytotal		number;
v_dailygender		number;  
v_dailyjuv			number; 
v_days				number; 
v_tcount			number;
v_mcount			number;
v_fcount			number;
v_jcount			number; 
v_total_count		number;
v_male_count		number;
v_female_count		number;
v_juvenile_count	number; 
v_BeginDate			date;
v_EndDate			date;
p_as_of_date		date;
v_total_average		number;
v_male_average		number;
v_female_average	number;
v_juvenile_average	number;

--Error trapping/logging procedures
PROCEDURE log_error (p_code IN integer, p_message IN varchar2)
	IS
		BEGIN
			EPIC.ep_log_info (cs_mod/*p_module_id*/,'E'/*p_logtype*/,-1/*p_action_by,*/,'(' || p_code || ') ' || p_message/*p_text*/);
			RETURN;
		END;

PROCEDURE logit (p_text	IN	varchar2)
	IS
		BEGIN
			IF gv_debug THEN
				EPIC.ep_log_info (cs_mod,'D',-1,p_text);
			END IF;
			RETURN;
		END;
          

--get the location_id for 'WRIT' (inmates on WRIT are not counted in the daily count)
FUNCTION procWrit
	RETURN EPIC.epic_locations.location_id%type
	IS
		BEGIN
			SELECT	location_id
			INTO	v_writ
			FROM	EPIC.epic_locations
			WHERE 	location_name = 'WRIT';
			RETURN v_writ;
		END; 

-----------------------------------Procedures to return the counts for each day----------------------------------
FUNCTION funcTotal	(p_date	in	date)
	RETURN number 
	IS
		BEGIN
			SELECT	count(distinct entity_id)
			INTO	v_dailytotal
			FROM	EPICAUDIT.eh_housing_assignments ha
			WHERE	EPIC.ef_epic_date_to_date(ha.action_time) <= p_date
					and ha.muster_display_flag = 'Y'
					and ha.action_type = 'U'
					and ha.temporary_location_flag = 'N'
					and ha.location_id != v_writ
					and not exists (
						--Exclude housing changes
						SELECT	entity_id
						FROM	EPICAUDIT.eh_housing_assignments ha2
						WHERE	ha2.entity_id = ha.entity_id
								and ha2.muster_display_flag = 'Y'
								and (ha2.action_time > ha.action_time
								-- Exclude changes where action types 'U' and 'D' are done at the same time
								or (ha2.action_type <> ha.action_type
									and ha2.action_time = ha.action_time
									and ha2.location_id = ha.location_id))
								and EPIC.ef_epic_date_to_date(ha2.action_time) <= p_date
									)
					 and not exists (
						--Exclude updates of any kind
						SELECT 	entity_id
						FROM	EPICAUDIT.eh_housing_assignments ha2
						WHERE 	ha2.entity_id = ha.entity_id
								and ha2.location_id = ha.location_id
								and ha2.action_time > ha.action_time
								and EPIC.ef_epic_date_to_date(ha2.action_time) < p_date
									)
					and not exists (
						--Exclude inmates that were merged
						SELECT	entity_id
						FROM	EPICAUDIT.eh_entity et
						WHERE	et.entity_id = ha.entity_id
								and EPIC.ef_epic_date_to_date(et.action_time) <= p_date
								and et.action_type = 'D'
									) ;  
			RETURN NVL(v_dailytotal,0);
		END;                       

FUNCTION funcGender	(p_date	in	date, p_gender in varchar2) 
	RETURN number
	IS
		BEGIN 
			SELECT	count(distinct entity_id)
			INTO 	v_dailygender
			FROM	EPICAUDIT.eh_housing_assignments ha
			WHERE	EPIC.ef_epic_date_to_date(ha.action_time) <= p_date
					and ha.muster_display_flag = 'Y'
					and ha.action_type = 'U'
					and ha.temporary_location_flag = 'N'
					and ha.location_id != v_writ
					and MACOMB.mcmb_fnt_gendershort(ha.entity_id) = p_gender
					and not exists (
						--Exclude housing changes
						SELECT	entity_id
						FROM	EPICAUDIT.eh_housing_assignments ha2
						WHERE	ha2.entity_id = ha.entity_id
								and ha2.muster_display_flag = 'Y'
								and (ha2.action_time > ha.action_time
								-- Exclude changes where action types 'U' and 'D' are done at the same time
								or (ha2.action_type <> ha.action_type
									and ha2.action_time = ha.action_time
									and ha2.location_id = ha.location_id))
								and EPIC.ef_epic_date_to_date(ha2.action_time) <= p_date
									)
					 and not exists (
						--Exclude updates of any kind
						SELECT 	entity_id
						FROM	EPICAUDIT.eh_housing_assignments ha2
						WHERE 	ha2.entity_id = ha.entity_id
								and ha2.location_id = ha.location_id
								and ha2.action_time > ha.action_time
								and EPIC.ef_epic_date_to_date(ha2.action_time) < p_date
									)
					and not exists (
						--Exclude inmates that were merged
						SELECT	entity_id
						FROM	EPICAUDIT.eh_entity et
						WHERE	et.entity_id = ha.entity_id
								and EPIC.ef_epic_date_to_date(et.action_time) <= p_date
								and et.action_type = 'D'
									) ; 
				RETURN NVL(v_dailygender,0);
			END;


FUNCTION funcJuv	(p_date	in date)
	RETURN number
	IS
		BEGIN 
			SELECT	count(distinct entity_id)
			INTO	v_dailyjuv
			FROM	EPICAUDIT.eh_housing_assignments ha
			WHERE	EPIC.ef_epic_date_to_date(ha.action_time) <= p_date
					and ha.muster_display_flag = 'Y'
					and ha.action_type = 'U'
					and ha.temporary_location_flag = 'N'
					and ha.location_id != v_writ
					and MACOMB.mf_JuvAudit(ha.entity_id, EPIC.epicdate(p_date)) = 'Y' 
					and not exists (
						--Exclude housing changes
						SELECT	entity_id
						FROM	EPICAUDIT.eh_housing_assignments ha2
						WHERE	ha2.entity_id = ha.entity_id
								and ha2.muster_display_flag = 'Y'
								and (ha2.action_time > ha.action_time
								-- Exclude changes where action types 'U' and 'D' are done at the same time
								or (ha2.action_type <> ha.action_type
									and ha2.action_time = ha.action_time
									and ha2.location_id = ha.location_id))
								and EPIC.ef_epic_date_to_date(ha2.action_time) <= p_date
									)
					 and not exists (
						--Exclude updates of any kind
						SELECT 	entity_id
						FROM	EPICAUDIT.eh_housing_assignments ha2
						WHERE 	ha2.entity_id = ha.entity_id
								and ha2.location_id = ha.location_id
								and ha2.action_time > ha.action_time
								and EPIC.ef_epic_date_to_date(ha2.action_time) < p_date
									)
					and not exists (
						--Exclude inmates that were merged
						SELECT	entity_id
						FROM	EPICAUDIT.eh_entity et
						WHERE	et.entity_id = ha.entity_id
								and EPIC.ef_epic_date_to_date(et.action_time) <= p_date
								and et.action_type = 'D'
									) ;
			RETURN NVL(v_dailyjuv,0); 
		END; 
                     
---------------------calculate actual averages-----------------------------------	
PROCEDURE Calculate (p_StartDate		in		EPIC.eh_housing_assignments.action_time%type,
					 p_EndDate			in		EPIC.eh_housing_assignments.action_time%type,
	 				 p_Cur 				in out 	EPIC.epp_generic_ref_cursor.ref_cursor)   
IS                                                      

BEGIN
v_BeginDate			:= EPIC.ef_epic_date_to_date(EPIC.ef_min_date(p_StartDate)) + 2/24;
v_EndDate			:= EPIC.ef_epic_date_to_date(EPIC.ef_min_date(p_EndDate)) + 2/24;
v_tcount 			:= 0; 
v_mcount 			:= 0;
v_fcount 			:= 0;
v_jcount 			:= 0;
v_total_count 		:= 0;
v_male_count 		:= 0;
v_female_count 		:= 0;
v_juvenile_count	:= 0;
v_days 				:= 0;
p_as_of_date 		:= v_BeginDate;
v_juvenile_average  := 0;
v_female_average    := 0;
v_male_average      := 0;
v_total_average     := 0;

--Run function to find the epic ID for WRIT location
v_writ := procWrit;

--initial entry in log
logit('adequate tcount   Current    Total');	
	
	WHILE p_as_of_date <= v_EndDate
		LOOP   
			logit('adequate date ' ||p_as_of_date );
		
			v_tcount := funcTotal(p_as_of_date);
			v_mcount := funcGender(p_as_of_date,'M');
			v_fcount := funcGender(p_as_of_date,'F');
			v_jcount := funcJuv(p_as_of_date);
			
    		v_total_count := v_total_count + v_tcount; 
    		v_male_count := v_male_count + v_mcount;
    		v_female_count := v_female_count + v_fcount;
		    v_juvenile_count := v_juvenile_count + v_jcount;   
			
			logit('adequate tcount' ||v_tcount || ' '|| v_total_count);
			logit('adequate male' ||v_mcount || ' '||v_male_count );
			logit('adequate female' ||v_fcount || ' '||v_female_count );
			logit('adequate juv' ||v_jcount || ' '||v_juvenile_count );
				
			p_as_of_date := p_as_of_date + 1;
			v_days := v_days + 1;
		END LOOP; 
		
v_total_average := v_total_count / v_days;  
v_male_average := v_male_count / v_days;
v_female_average := v_female_count / v_days;
v_juvenile_average := v_juvenile_count / v_days;  

OPEN p_Cur FOR
	SELECT 	v_total_average as TotalAvg,
			v_male_average as MaleAvg, 
			v_female_average as FemaleAvg, 
			v_juvenile_average as JuvAvg, 
			v_days as vDays 
	FROM 	dual;
	
logit('adequate average total' ||v_total_average);
logit('adequate average male' ||v_male_average);
logit('adequate average female' ||v_female_average);
logit('adequate average juv' ||v_juvenile_average);

--end of procedure Calculate
END; 

--package end
END; 
/
