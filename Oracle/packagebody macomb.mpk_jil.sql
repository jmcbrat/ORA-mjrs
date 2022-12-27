CREATE OR REPLACE
package body        MPK_JIL is
/*	Purpose:		Macomb JIL internet - This is the process to make the triggering of who gets copied and not.
	Process:		Register the request, signal the action in a trigger, create a job to run (that moves the 
					data from OT to JIL.  All procedures are included in this package to handle alert, signal, 
					and create job functionality.
					
					The selected data has its own procedures and functions that are more global in nature.
	                
					
	Author:			Joe McBratnie
	
	Change Log:		Changed By	  Date Modified		Change Made
					------------  -------------		---------------------------------
					J. MCBRATNIE  	08/15/06		Created 

*/ 	


	--
	cs_mod							constant varchar2(255) := 'JIL';
	--
	--
	--		server type = Unix (true) or NT (false)
	--
	--
	c_server_unix					constant boolean := FALSE;
	cs_debug						constant epic.epic_configuration.config_key%type := 'ENABLE LOGGING';
	cs_enabled						constant epic.epic_configuration.config_key%type := 'ENABLED';
	--
	--		last configuration values - write new config file when they change
	--
	gv_debug						boolean := false;
	--
	gv_retry_period					integer;
	gv_enabled						char(1);
	--
	--		current sequence number for file names
	--
	gv_seq_num						integer := 1;
	--
	--		standard character definitions used for Ascribe interface
	--
	cCR								constant char(1) := chr(13);
	cLF								constant char(1) := chr(10);
	cCRLF							constant char(2) := chr(13) || chr(10);
	cSep							constant char(1) := '|';
	cBell							constant char(1) := chr(07);
	--
	--		end of line constants for unix/nt
	--
	cUnix_EOLN						constant char(1) := chr(10);
	cNT_EOLN						constant char(2) := chr(13) || chr(10);

--------------------------------------------
--LOCAL Support PROCEDURES and FUNCTIONS  --
--------------------------------------------

	--
	--	internal procedure to log errors
	--
	procedure log_error (
		p_code				in		integer,
		p_message			in		varchar2)
	is
	begin
		epic.ep_log_info (
			cs_mod,						--	p_module_id,
			'E',						--	p_logtype,
			-1,	--	p_action_by,
			'(' || p_code || ') ' || p_message);	--	p_text);
		return;
	end;

	--
	--	internal procedure for debug logging
	--
	procedure ConvertDate(
		p_epic_date			in		epic.eh_entity_person.action_time%type,
		p_string_date		in out  varchar2,
		p_string_time		in out  varchar2)
	is
		p_oracle_date		date;
	begin
		if not p_epic_date is null then
			p_oracle_date := epic.ef_epic_date_to_date(p_epic_date);
			p_string_date := to_char(p_oracle_date,'yyyymmdd');
			p_string_time := to_char(p_oracle_date,'hh24MI');
		end if;

		return;
	end;

	--
	--	internal procedure for stoing the message
	--
	procedure logit (
		p_text				in		varchar2)
	is
	begin
		if gv_debug then
			epic.ep_log_info (
				cs_mod,
				'D',
				-1,
				p_text);
		end if;
		return;
	end;

	--
	--	internal procedure for handleing nul data in file write
	--
	function nonnull(
		p_text				in		varchar2
		) return varchar2
	is
		v_return varchar2(128);
	begin
		if p_text is null then
			v_return := ' ';
		else
			v_return := p_text;
		end if;

		return v_return;
	end;                                                       
	
	--
	--
	--
	--	procedure to get the current system configuration parameters
	--
	--
	procedure get_configuration (
		p_path				in out	epic.epic_configuration.config_value%type,
		p_file_name			in out  epic.epic_configuration.config_value%type,
		p_synch_file_name	in out  epic.epic_configuration.config_value%type,
		p_sending_agency_id	in out	epic.epic_configuration.config_value%type,
		p_adult_age			in out	integer,
		p_suppress_ssn		in out  boolean,
		p_enabled			in out	char)
	is
		v_debug					epic.epic_configuration.config_value%type;
		v_file_name				epic.epic_configuration.config_value%type;
		v_synch_file_name		epic.epic_configuration.config_value%type;
		v_path					epic.epic_configuration.config_value%type;
		v_sending_agency_id		epic.epic_configuration.config_value%type;
		v_adult_age_value		epic.epic_configuration.config_value%type;
		v_adult_age				integer;
		v_suppress_ssn			epic.epic_configuration.config_value%type;
		v_enabled_value			epic.epic_configuration.config_value%type;
		v_enabled				char(1);
		p_result				epic.epic_col_types.number_9%type;
		p_result_msg			epic.epic_col_types.varchar_255%type;
	begin
		--
		--	get debug flag value
		--
		epic.ep_get_configuration_value(cs_JIL_module, cs_debug, v_debug, 'N', p_result, p_result_msg);
		if upper(substr(v_debug, 1, 1)) = 'Y' then
			gv_debug := true;
		else
			gv_debug := false;
		end if;
		--
		--	get interface enabled flag
		--
		epic.ep_get_configuration_value(cs_JIL_module, cs_enabled, v_enabled_value, 'Y', p_result, p_result_msg);
		v_enabled := upper(substr(v_enabled_value, 1, 1));
		if v_enabled not in ('Y','N') then
			raise_application_error(-20001, 'JIL Enabled value must be "Y" or "N" [' || v_enabled_value || ']');
		end if;
		--
		--	return values
		--
		p_enabled := v_enabled;
	end;


--------------------------------------------------
--LOCAL PROCEDURES and FUNCTIONS to do the work --
--------------------------------------------------
	--
	--	Procedure update JIL with ALIAS records for a given inmate
	--
	procedure jil_alias(
		p_message       in  varchar2,
		p_offender_id   in  varchar2)
	is
	begin 
		-- copy the data from OT to JIL
		logit('JIL alias'); 
		INSERT INTO MT_JIL_ALIAS@Link_IVR
		(ENTITY_ID_FK, OFFENDER_ID, ALIAS_ID_PK, LASTNAME, FIRSTNAME, MIDDLENAME, SUFFIXNAME, DOB, CODE_NAME_TYPE)
		(select 	id.entity_id AS entity_id,
			        id.OFFENDER_ID AS offender_id,
					pi.identity_id AS alias_id,
					pi.name_family AS lastname,
					pi.name_first  AS firstname,
					pi.name_other  AS middlename,
					pi.name_suffix AS suffixname,
			 	    NVL(NVL(to_char(EPIC.ef_epic_date_to_date(pi.DATE_OF_BIRTH),'MM/DD/YYYY'),
			 	    		to_char(EPIC.ef_epic_date_to_date(pi.BIRTH_DATE_APPROX),'MM/DD/YYYY')),
			 	                   'UNKNOWN') AS DOB,
			 	    pi.CODE_NAME_TYPE AS CODE_NAME_TYPE
			FROM    EPIC.eh_person_identity pi,
					EPIC.eh_offender_ids id
			WHERE	id.ENTITY_ID = pi.entity_id
			  AND	id.entity_id = p_message
			  AND	pi.CODE_NAME_TYPE in ('MAS','ALI')
			  AND EXISTS (select 1 from EPIC.eh_active_booking ab where id.entity_id = ab.entity_id));
		EXCEPTION 
			WHEN DUP_VAL_ON_INDEX THEN		
				UPDATE MT_JIL_ALIAS--@Link_IVR
				set (ENTITY_ID_FK, OFFENDER_ID, ALIAS_ID_PK, LASTNAME, FIRSTNAME, MIDDLENAME, SUFFIXNAME, DOB, CODE_NAME_TYPE) =
				(select 	id.entity_id AS entity_id,
					        id.OFFENDER_ID AS offender_id,
							pi.identity_id AS alias_id,
							pi.name_family AS lastname,
							pi.name_first  AS firstname,
							pi.name_other  AS middlename,
							pi.name_suffix AS suffixname,
					 	    NVL(NVL(to_char(EPIC.ef_epic_date_to_date(pi.DATE_OF_BIRTH),'MM/DD/YYYY'),
					 	    		to_char(EPIC.ef_epic_date_to_date(pi.BIRTH_DATE_APPROX),'MM/DD/YYYY')),
					 	                   'UNKNOWN') AS DOB,
					 	    pi.CODE_NAME_TYPE AS CODE_NAME_TYPE
					FROM    EPIC.eh_person_identity pi,
							EPIC.eh_offender_ids id
					WHERE	id.ENTITY_ID = pi.entity_id
					  AND	id.entity_id = p_message
					  AND	pi.CODE_NAME_TYPE in ('MAS','ALI')
					  AND EXISTS (select 1 from EPIC.eh_active_booking ab where id.entity_id = ab.entity_id));
		
		return;

	end;
	--
	
	--
	--	Procedure update JIL with inmate record
	--
	procedure jil_inmate(
		p_message       in  varchar2,
		p_offender_id   in  varchar2)
	is
	begin 
		-- copy the data from OT to JIL
		logit('JIL inmate');
				insert into MT_JIL_INMATE--@Link_IVR
				(ENTITY_ID_PK, OFFENDER_ID, INMATECLASS, LASTNAME, FIRSTNAME, OTHERNAME, GENDER, DOB, JUVENILE_FLAG, CELL, MUGPATH, TOW_COMPANY, SENT_TOTAL, HOLD_TOTAL, BAIL_TOTAL, PAID_RELEASE, PROJECTED_RELEASE, RESTRICTIONUNTIL)
				(select 	id.entity_id AS entity_id,
		       	id.OFFENDER_ID AS offender_id,
		   		decode(epic.ef_offender_CustStat(ab2.entity_id),
		               	'REGULAR INMATE','R',
						'WORK RELEASE','W',
		               	'KITCHEN TRUSTEE (White)','K',
		               	'GARAGE TRUSTEE (Orange)','O',
		               	'SPECIAL TRUSTEE (Green)','G',
		               	'R') as inmateclass,
				pi.NAME_FAMILY as lastname,
				pi.NAME_FIRST  as firstname,
				pi.NAME_OTHER  as othername,
		   		decode(ep.CODE_GENDER,'_NOSP','U',ep.CODE_GENDER) as gender,
				NVL(NVL(to_char(epic.ef_epic_date_to_date(pi.DATE_OF_BIRTH),'MM/DD/YYYY'),
						to_char(epic.ef_epic_date_to_date(pi.BIRTH_DATE_APPROX),'MM/DD/YYYY')),
						'UNKNOWN_DOB') as DOB,
				decode(ep.JUVENILE_FLAG,'Y','Y','N') as juvenile_flag,
			   	substr(epic.ef_location_name(ha.location_id ,'uc'),1,10) as cell,
				decode(ei.imageref, null,null,
						'\\' || ev.volumeserver || '\F$\FTP\' || ev.volumepath || '\' || ei.imageref) as mugpath,
				--vehicle_id as vehicle_id,
				eo.ORGANIZATION_NAME as tow_company,
		   	   	EPIC.mcmb_fnt_sent_Total_Amount(ab2.booking_id) as sent_total,
		   	   	EPIC.mcmb_fnt_hold_Total_Amount(ab2.booking_id) as hold_total,
		   		EPIC.mcmb_fnt_Bail_Total_Amount(ab2.booking_id) as bail_total,
				epic.ef_epic_date_to_date(epic.epp_booking_dates.earliest_release_date(ab2.booking_id)) as paid_release,
		   	   	epic.ef_epic_date_to_date(epic.epp_booking_dates.final_release_date(ab2.booking_id))    as Projected_release,--,
		   	   	(select max(epic.ef_epic_date_to_date(r.end_date)) from epic.EH_ENTITY_RESTRICTION r where ab2.entity_id = r.entity_id(+) and epic.ef_epic_date_to_date(r.end_date)>sysdate ) as restrictionuntil
		 from   epic.EH_OFFENDER_IDS id,
		 		epic.EH_PERSON_IDENTITY pi,
		 		epic.eh_entity_person ep,
		 		epic.EH_VEHICLE v,
				epic.EH_ENTITY_ORGANIZATION  eo,
				epic.Epicvolume ev,
				epic.Epicimage ei,
				epic.Eh_entity_default_photo ph,
				epic.eh_active_booking ab2,
				epic.eh_housing_assignments ha
		 where  id.entity_id = ab2.entity_id
		   and  epic.ef_is_active_booking(ab2.entity_id)='TRUE'
		   and  id.entity_id = p_message
		   and  id.entity_id = pi.entity_id
		   and  id.entity_id = ep.entity_id
		   and  ab2.entity_id = ha.entity_id
		   and  v.entity_id(+) = pi.entity_id
		   and  v.tow_company_id = eo.entity_id(+)
		   and  ei.imageref(+) = ph.photo_id
		   and  ev.volumeid(+) = ei.volumeid
		   and  ph.entity_id(+) = id.entity_id
		   and  pi.code_name_type = 'MAS'
		   and  ab2.entity_id = id.entity_id);
		EXCEPTION 
			WHEN DUP_VAL_ON_INDEX THEN		
				UPDATE MT_JIL_INMATE--@Link_IVR
				 set (ENTITY_ID_PK, OFFENDER_ID, INMATECLASS, LASTNAME, FIRSTNAME, OTHERNAME, GENDER, DOB, JUVENILE_FLAG, CELL, MUGPATH, TOW_COMPANY, SENT_TOTAL, HOLD_TOTAL, BAIL_TOTAL, PAID_RELEASE, PROJECTED_RELEASE, RESTRICTIONUNTIL)
				=(	select 	id.entity_id AS entity_id,
					       	id.OFFENDER_ID AS offender_id,
					   		decode(epic.ef_offender_CustStat(ab2.entity_id),
					               	'REGULAR INMATE','R',
									'WORK RELEASE','W',
					               	'KITCHEN TRUSTEE (White)','K',
					               	'GARAGE TRUSTEE (Orange)','O',
					               	'SPECIAL TRUSTEE (Green)','G',
					               	'R') as inmateclass,
							pi.NAME_FAMILY as lastname,
							pi.NAME_FIRST  as firstname,
							pi.NAME_OTHER  as othername,
					   		decode(ep.CODE_GENDER,'_NOSP','U',ep.CODE_GENDER) as gender,
							NVL(NVL(to_char(epic.ef_epic_date_to_date(pi.DATE_OF_BIRTH),'MM/DD/YYYY'),
									to_char(epic.ef_epic_date_to_date(pi.BIRTH_DATE_APPROX),'MM/DD/YYYY')),
									'UNKNOWN_DOB') as DOB,
							decode(ep.JUVENILE_FLAG,'Y','Y','N') as juvenile_flag,
						   	substr(epic.ef_location_name(ha.location_id ,'uc'),1,10) as cell,
							decode(ei.imageref, null,null,
									'\\' || ev.volumeserver || '\F$\FTP\' || ev.volumepath || '\' || ei.imageref) as mugpath,
							--vehicle_id as vehicle_id,
							eo.ORGANIZATION_NAME as tow_company,
					   	   	EPIC.mcmb_fnt_sent_Total_Amount(ab2.booking_id) as sent_total,
					   	   	EPIC.mcmb_fnt_hold_Total_Amount(ab2.booking_id) as hold_total,
					   		EPIC.mcmb_fnt_Bail_Total_Amount(ab2.booking_id) as bail_total,
							epic.ef_epic_date_to_date(epic.epp_booking_dates.earliest_release_date(ab2.booking_id)) as paid_release,
					   	   	epic.ef_epic_date_to_date(epic.epp_booking_dates.final_release_date(ab2.booking_id))    as Projected_release,--,
					   	   	(select max(epic.ef_epic_date_to_date(r.end_date)) from epic.EH_ENTITY_RESTRICTION r where ab2.entity_id = r.entity_id(+) and epic.ef_epic_date_to_date(r.end_date)>sysdate ) as restrictionuntil
					 from   epic.EH_OFFENDER_IDS id,
					 		epic.EH_PERSON_IDENTITY pi,
					 		epic.eh_entity_person ep,
					 		epic.EH_VEHICLE v,
							epic.EH_ENTITY_ORGANIZATION  eo,
							epic.Epicvolume ev,
							epic.Epicimage ei,
							epic.Eh_entity_default_photo ph,
							epic.eh_active_booking ab2,
							epic.eh_housing_assignments ha
					 where  id.entity_id = ab2.entity_id
					   and  epic.ef_is_active_booking(ab2.entity_id)='TRUE'
					   and  id.entity_id = p_message
					   and  id.entity_id = pi.entity_id
					   and  id.entity_id = ep.entity_id
					   and  ab2.entity_id = ha.entity_id
					   and  v.entity_id(+) = pi.entity_id
					   and  v.tow_company_id = eo.entity_id(+)
					   and  ei.imageref(+) = ph.photo_id
					   and  ev.volumeid(+) = ei.volumeid
					   and  ph.entity_id(+) = id.entity_id
					   and  pi.code_name_type = 'MAS'
					   and  ab2.entity_id = id.entity_id); 		
		
		
		return;

	end;
	--
	
	--
	--	Procedure update JIL with VISITOR records for a given inmate
	--  p_message is the EPIC.eh_offender_ids.entity_id
	--
	procedure jil_visitor(
		p_message       in  varchar2,
		p_offender_id   in  varchar2)
	is
	begin 
		-- copy the data from OT to JIL
		logit('JIL visitor'); 
		insert into  MT_JIL_VISITOR--@Link_IVR
		(ENTITY_ID_fk, offender_id, entity_related_to_pk, APPLICATION_DATE, EXPIRATION_DATE, LASTNAME, FIRSTNAME, STATUS, TYPESEQ)
			SELECT 	id.entity_id AS entity_id_fk,
			        id.offender_id AS entity_id, 
					er.ENTITY_RELATED_TO AS entity_related_to_pk,
					DECODE(er.RELATIONSHIP_TYPE,'21',NVL(to_char(EPIC.ef_epic_date_to_date(EPIC.mcmb_fnt_Vist_app_date(er.ENTITY_RELATED_TO)),'MM/DD/YYYY'),'unknown'),null) AS application_date,
			       	DECODE(er.RELATIONSHIP_TYPE,'21',NVL(to_char(EPIC.ef_epic_date_to_date(EPIC.mcmb_fnt_Vist_expir_date(er.ENTITY_RELATED_TO)),'MM/DD/YYYY'),'unknown'),null) AS expiration_date,
			       	pi.name_family AS lastname,
			       	pi.name_first  AS firstname,
			       	DECODE(er.RELATIONSHIP_TYPE,'21','A','N') AS status,
			       	DECODE(er.RELATIONSHIP_TYPE,'21','1','2') AS typeseq--,
			   	   	--id.offender_id ||'-'||er.ENTITY_RELATED_TO AS vistitor_pk
			FROM   	EPIC.eh_offender_ids id,
					EPIC.eh_person_identity pi,
			       	EPIC.eh_entity_relationship er
			--       	EPIC.eh_active_booking ab
			WHERE  er.ENTITY_RELATED_TO = pi.entity_id
			--  AND  ab.entity_id = pi.entity_id
			  AND  id.entity_id = er.entity_id
			  AND  er.related_as_role = 'VISTR'
			  AND  pi.code_name_type = 'MAS'   
			  AND  id.entity_id = p_message
			  AND EXISTS (select 1 from EPIC.eh_active_booking ab where pi.entity_id = ab.entity_id);
		EXCEPTION 
			WHEN DUP_VAL_ON_INDEX THEN
				UPDATE MT_JIL_VISITOR--@Link_IVR
				 set (ENTITY_ID_fk, offender_id, entity_related_to_pk, APPLICATION_DATE, EXPIRATION_DATE, LASTNAME, FIRSTNAME, STATUS, TYPESEQ/*, VISTITOR_PK*/) = 
					(SELECT id.entity_id AS entity_id_fk,
					        id.offender_id AS entity_id, 
							er.ENTITY_RELATED_TO AS entity_related_to_pk,
							DECODE(er.RELATIONSHIP_TYPE,'21',NVL(to_char(EPIC.ef_epic_date_to_date(EPIC.mcmb_fnt_Vist_app_date(er.ENTITY_RELATED_TO)),'MM/DD/YYYY'),'unknown'),null) AS application_date,
					       	DECODE(er.RELATIONSHIP_TYPE,'21',NVL(to_char(EPIC.ef_epic_date_to_date(EPIC.mcmb_fnt_Vist_expir_date(er.ENTITY_RELATED_TO)),'MM/DD/YYYY'),'unknown'),null) AS expiration_date,
					       	pi.name_family AS lastname,
					       	pi.name_first  AS firstname,
					       	DECODE(er.RELATIONSHIP_TYPE,'21','A','N') AS status,
					       	DECODE(er.RELATIONSHIP_TYPE,'21','1','2') AS typeseq--,
					   	   	--id.offender_id ||'-'||er.ENTITY_RELATED_TO AS vistitor_pk
					FROM   	EPIC.eh_offender_ids id,
							EPIC.eh_person_identity pi,
					       	EPIC.eh_entity_relationship er
					--       	EPIC.eh_active_booking ab
					WHERE  er.ENTITY_RELATED_TO = pi.entity_id
					--  AND  ab.entity_id = pi.entity_id
					  AND  id.entity_id = er.entity_id
					  AND  er.related_as_role = 'VISTR'
					  AND  pi.code_name_type = 'MAS'   
					  AND  id.entity_id = p_message
					  AND EXISTS (select 1 from EPIC.eh_active_booking ab where pi.entity_id = ab.entity_id)
				);
		return;
	end;
	--

	--
	--	Procedure update JIL with BANNED records for a given inmate
	--  p_message is the EPIC.eh_banned_visitor.visitor_id
	--
	procedure jil_banned
	is
	begin 
		-- copy the data from OT to JIL
		
		logit('JIL banned'); 
		begin
			insert into MT_JIL_VISITOR--@Link_IVR
			(ENTITY_ID_fk, offender_id, entity_related_to_pk, APPLICATION_DATE, EXPIRATION_DATE, LASTNAME, FIRSTNAME, STATUS, TYPESEQ/*, VISTITOR_PK*/)
				SELECT 	'' AS ENTITY_ID_fk, 
				        null as  offender_id,
						va.visitor_id AS vistitor_id, 
						va.date_FROM AS application_date, 
						va.date_to AS expiration_date, 
						vpi.name_family AS lastname, 
						vpi.name_first  AS firstname, 
						'B' AS status, 
						'3' AS typeseq--,
						--''||'-'||va.VISITOR_ID
				FROM 	EPIC.eh_banned_visitor va, 
						EPIC.eh_person_identity vpi,
				      	EPIC.eh_active_booking ab
				WHERE 	va.visitor_id = vpi.entity_id
				  AND	ab.entity_id = vpi.entity_id 
				  --AND   vpi.entity_id = p_message
				  AND EXISTS (select 1 from EPIC.eh_active_booking ab where vpi.entity_id = ab.entity_id);           
		EXCEPTION 
			WHEN DUP_VAL_ON_INDEX THEN
				UPDATE MT_JIL_VISITOR--@Link_IVR
				SET (ENTITY_ID_fk, offender_id, entity_related_to_pk, APPLICATION_DATE, EXPIRATION_DATE, LASTNAME, FIRSTNAME, STATUS, TYPESEQ/*, VISTITOR_PK*/) = 
				(	SELECT 	'' AS ENTITY_ID_fk, 
   				            null as  offender_id,
							va.visitor_id AS vistitor_id, 
							va.date_FROM AS application_date, 
							va.date_to AS expiration_date, 
							vpi.name_family AS lastname, 
							vpi.name_first  AS firstname, 
							'B' AS status, 
							'3' AS typeseq--,
							--''||'-'||va.VISITOR_ID
					FROM 	EPIC.eh_banned_visitor va, 
							EPIC.eh_person_identity vpi,
					       	EPIC.eh_active_booking ab
					WHERE 	va.visitor_id = vpi.entity_id
					  AND	ab.entity_id = vpi.entity_id 
					  --AND   vpi.entity_id = p_message
					  AND EXISTS (select 1 from EPIC.eh_active_booking ab where vpi.entity_id = ab.entity_id));
		end;		
		return;
	end;
	--

	--
	--	Procedure update JIL with CHARGE records for a given inmate
	--
	procedure jil_charge(
		p_message       in  varchar2,
		p_offender_id   in  varchar2)
	is
	begin 
		-- copy the data from OT to JIL
		logit('JIL charge');
		insert into MT_JIL_CHARGE--@Link_IVR
		(ENTITY_ID_FK, OFFENDER_ID, CHARGE_ID, STATUTE_ID, PACC, CHARGE_DESC, CHARGE_CLASS,
		SENTENCE_ID, CHARGE_ID_NUMBER, AGENCY_ID, COMPLAINT_DEPT, COURT_ID, CASE_NO, COURT_NAME, 
		COURT_DATE, COURT_DIVISION, JUDGE, START_DATE, FINAL_RELEASE_DATE, AMOUNT, AMOUNT_TYPE, 
		TRANS_TYPE, SORT_ORDER, REDUCEAMOUNT, PAIDOUTDATE, UNPAIDOUTDATE, surcharge_amount,
		charge_state)
		SELECT 	b.entity_id                AS entity_id,
		        id.OFFENDER_ID				AS offender_id,
				c.charge_id 				AS charge_id,
		        c.statute_id 				AS statute_id,
		        es.statute_number 			AS pacc,
		        es.statute_description 		AS charge_desc,
		    	EPIC.ef_lookup_text('STATUTE CLASS', es.code_statute_class, 'UC') AS charge_class,
		        s.sentence_id 				AS sentence_id,
		       	charge_id_number 			AS charge_id_number,
		       	ca.agency_id 				AS agency_id,
		       	eo.organization_name 		AS complaint_dept,
		       	cct.court_id 				AS court_id,
		       	cs.case_number 				AS case_no,
		       	EPIC.mcmb_fnt_courtname(c.charge_id) AS court_name,
		       	decode(
		       	to_char(EPIC.ef_epic_date_to_date(EPIC.ef_next_court_date(b.entity_id)),'MM/DD/YYYY'),'12/25/2025','Call Court',
		       	                                                                                      '01/01/2200','Call Court',
		       	to_char(EPIC.ef_epic_date_to_date(EPIC.ef_next_court_date(b.entity_id)),'MM/DD/YYYY')) AS court_date,
		       	EPIC.ef_next_court_division(b.entity_id) AS court_division,
		       	EPIC.ef_lookup_text('JUDGE NAME',EPIC.ef_next_court_judge(b.entity_id),'UC') AS court_judge,
				EPIC.ef_epic_date_to_date(EPIC.epp_booking_dates.start_date(b.booking_id))         		AS Start_Date,
				EPIC.ef_epic_date_to_date(EPIC.epp_booking_dates.final_release_date(b.booking_id))     	AS final_release_date ,
				decode(c.sentence_id,NULL,
									to_number(bc.cash_only_bail_amount),
									to_number(EPIC.mcmb_fnt_fineamount(c.sentence_id)))  AS amount,
				decode(c.sentence_id,NULL, 'BAIL', 'FINE') AS amount_type,
				decode(c.sentence_id,NULL, 'U', 'S') AS Trans_type,
				decode(c.sentence_id,NULL, 2, 1) AS sortorder,
				--EPIC.ef_offender_id(b.entity_id)||' - '||c.charge_id  AS web_charge_pk,
				decode(EPIC.ef_get_attribute_value('10 PERCENT BOND',bc.BAIL_CONDITION_ID),'YES',
																	'Y',
																	'N') AS reduceamount,
				EPIC.ef_epic_date_to_date(so.paid_out_date) AS paidoutdate,
				EPIC.ef_epic_date_to_date(so.unpaid_out_date) AS unpaidoutdate,
				bc.surcharge_amount  AS surcharge_amount,
				c.charge_state
		FROM 	EPIC.eh_charge c,
				EPIC.eh_booking b,
				EPIC.eh_active_booking ab,
				EPIC.eh_charge_agency ca ,
		     	EPIC.eh_case cs,
		     	EPIC.eh_case_charge cc,
		     	EPIC.eh_case_court cct,
		     	EPIC.eh_entity_organization eo,
		     	EPIC.eh_sentence s,
		     	EPIC.eh_sentence_out_dates so,
		     	EPIC.epic_statutes es,
		     	EPIC.eh_bail_condition bc,
		     	EPIC.eh_bail_condition_charge bcc,
				EPIC.eh_offender_ids id
		WHERE b.booking_id = c.booking_id
		  AND c.charge_id = ca.charge_id
		  AND b.booking_id = p_message
		  AND s.sentence_id (+) = c.sentence_id
		  AND cs.booking_id = b.booking_id
		  AND cc.charge_id = c.charge_id
		  AND cc.case_id = cs.case_id
		  AND cct.case_id = cs.case_id
		  AND eo.entity_id = ca.agency_id
		  AND es.STATUTE_ID = c.statute_id
		  AND so.sentence_id (+)  = c.sentence_id
		  AND bc.booking_id = b.booking_id
		  AND bcc.charge_id = c.charge_id
		  AND bc.bail_condition_id = bcc.bail_condition_id
		  AND b.booking_id = ab.booking_id
		  AND id.ENTITY_ID = ab.entity_id
		  AND EPIC.ef_is_active_booking(b.entity_id)='TRUE'
		union
		-- HOLD records
		SELECT b.entity_id AS entity_id,
		       EPIC.ef_offender_id(b.entity_id) AS offender_id,
		       h.hold_id AS charge_id,
			   NULL      AS statute_id,
		       NULL      AS pacc,
		       NULL      AS charge_desc,
		       EPIC.ef_lookup_text('STATUTE CLASS', code_charge_severity, 'UC') AS charge_class,
		       NULL                 AS sentence_id,
		       EPIC.ef_lookup_text('HOLD TYPE',code_hold_type,'UC') AS charge_id_number,
		       h.agency_id          AS agency_id,
		       eo.organization_name AS complaint_dept,
		       NULL                 AS court_id,
		       -- case number (other attrib - hold warant number)
		       EPIC.ef_get_attribute_value('HOLD WARRANT NUMBER',h.hold_id) AS case_no,
		       -- court name  (other attrib - hold court)
		       EPIC.ef_get_attribute_value('HOLD COURT',h.hold_id) AS court_name,
		       NULL AS court_date,
		       NULL AS court_division,
		       NULL AS court_judge,
		       NULL AS start_date,
		       NULL AS final_release_date,
		       -- bond/fines  (other attrib - hold amount)
		       to_number(EPIC.ef_get_attribute_value('HOLD AMOUNT',h.hold_id)) AS amount,
		       'BOND' AS amount_type,
			   'H'    AS Trans_type,
		       3      AS sortorder,
		        --EPIC.mcmb_fnt_offenderidfrombk(b.booking_id)||' - '||h.hold_id,
		   	    decode(sign(instr(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id),'10%')+
		  					instr(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id),'10 %')+
		   					instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'10 PERCENT'))-
		   					(instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'NO 10')*100)-
		   					(instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'NO10')*100),
						  					1,'Y','N') AS reduceamount,
				NULL AS paidoutdate,
				NULL AS unpaidoutdate,
				NULL AS surcharge_amount,
				NULL AS charge_state
		FROM EPIC.eh_booking_holds h,
		     EPIC.eh_active_booking b,
		     EPIC.eh_entity_organization eo
		WHERE b.booking_id = h.booking_id
		  AND eo.entity_id = h.agency_id
		  AND b.booking_id = p_message;
		EXCEPTION 
			WHEN DUP_VAL_ON_INDEX THEN
				UPDATE MT_JIL_CHARGE--@Link_IVR
				set (ENTITY_ID_FK, OFFENDER_ID, CHARGE_ID, STATUTE_ID, PACC, CHARGE_DESC, CHARGE_CLASS,
					SENTENCE_ID, CHARGE_ID_NUMBER, AGENCY_ID, COMPLAINT_DEPT, COURT_ID, CASE_NO, COURT_NAME, 
					COURT_DATE, COURT_DIVISION, JUDGE, START_DATE, FINAL_RELEASE_DATE, AMOUNT, AMOUNT_TYPE, 
					TRANS_TYPE, SORT_ORDER, REDUCEAMOUNT, PAIDOUTDATE, UNPAIDOUTDATE, surcharge_amount,
					charge_state)=
					(SELECT b.entity_id                AS entity_id,
					        id.OFFENDER_ID				AS offender_id,
							c.charge_id 				AS charge_id,
					        c.statute_id 				AS statute_id,
					        es.statute_number 			AS pacc,
					        es.statute_description 		AS charge_desc,
					    	EPIC.ef_lookup_text('STATUTE CLASS', es.code_statute_class, 'UC') AS charge_class,
					        s.sentence_id 				AS sentence_id,
					       	charge_id_number 			AS charge_id_number,
					       	ca.agency_id 				AS agency_id,
					       	eo.organization_name 		AS complaint_dept,
					       	cct.court_id 				AS court_id,
					       	cs.case_number 				AS case_no,
					       	EPIC.mcmb_fnt_courtname(c.charge_id) AS court_name,
					       	decode(
					       	to_char(EPIC.ef_epic_date_to_date(EPIC.ef_next_court_date(b.entity_id)),'MM/DD/YYYY'),'12/25/2025','Call Court',
					       	                                                                                      '01/01/2200','Call Court',
					       	to_char(EPIC.ef_epic_date_to_date(EPIC.ef_next_court_date(b.entity_id)),'MM/DD/YYYY')) AS court_date,
					       	EPIC.ef_next_court_division(b.entity_id) AS court_division,
					       	EPIC.ef_lookup_text('JUDGE NAME',EPIC.ef_next_court_judge(b.entity_id),'UC') AS court_judge,
							EPIC.ef_epic_date_to_date(EPIC.epp_booking_dates.start_date(b.booking_id))         		AS Start_Date,
							EPIC.ef_epic_date_to_date(EPIC.epp_booking_dates.final_release_date(b.booking_id))     	AS final_releASe_date ,
							decode(c.sentence_id,NULL,
												to_number(bc.cash_only_bail_amount),
												to_number(EPIC.mcmb_fnt_fineamount(c.sentence_id)))  AS amount,
							decode(c.sentence_id,NULL, 'BAIL', 'FINE') AS amount_type,
							decode(c.sentence_id,NULL, 'U', 'S') AS Trans_type,
							decode(c.sentence_id,NULL, 2, 1) AS sortorder,
							--EPIC.ef_offender_id(b.entity_id)||' - '||c.charge_id  AS web_charge_pk,
							decode(EPIC.ef_get_attribute_value('10 PERCENT BOND',bc.BAIL_CONDITION_ID),'YES',
																				'Y',
																				'N') AS reduceamount,
							EPIC.ef_epic_date_to_date(so.paid_out_date) AS paidoutdate,
							EPIC.ef_epic_date_to_date(so.unpaid_out_date) AS unpaidoutdate,
							bc.surcharge_amount  AS surcharge_amount,
							c.charge_state
					FROM 	EPIC.eh_charge c,
							EPIC.eh_booking b,
							EPIC.eh_active_booking ab,
							EPIC.eh_charge_agency ca ,
					     	EPIC.eh_case cs,
					     	EPIC.eh_case_charge cc,
					     	EPIC.eh_case_court cct,
					     	EPIC.eh_entity_organization eo,
					     	EPIC.eh_sentence s,
					     	EPIC.eh_sentence_out_dates so,
					     	EPIC.epic_statutes es,
					     	EPIC.eh_bail_condition bc,
					     	EPIC.eh_bail_condition_charge bcc,
							EPIC.eh_offender_ids id
					WHERE b.booking_id = c.booking_id
					  AND c.charge_id = ca.charge_id
					  AND b.booking_id = p_message
					  AND s.sentence_id (+) = c.sentence_id
					  AND cs.booking_id = b.booking_id
					  AND cc.charge_id = c.charge_id
					  AND cc.case_id = cs.case_id
					  AND cct.case_id = cs.case_id
					  AND eo.entity_id = ca.agency_id
					  AND es.STATUTE_ID = c.statute_id
					  AND so.sentence_id (+)  = c.sentence_id
					  AND bc.booking_id = b.booking_id
					  AND bcc.charge_id = c.charge_id
					  AND bc.bail_condition_id = bcc.bail_condition_id
					  AND b.booking_id = ab.booking_id
					  AND id.ENTITY_ID = ab.entity_id
					  AND EPIC.ef_is_active_booking(b.entity_id)='TRUE'
					union
					-- HOLD records
					SELECT b.entity_id AS entity_id,
					       EPIC.ef_offender_id(b.entity_id) AS offender_id,
					       h.hold_id AS charge_id,
						   NULL      AS statute_id,
					       NULL      AS pacc,
					       NULL      AS charge_desc,
					       EPIC.ef_lookup_text('STATUTE CLASS', code_charge_severity, 'UC') AS charge_class,
					       NULL                 AS sentence_id,
					       EPIC.ef_lookup_text('HOLD TYPE',code_hold_type,'UC') AS charge_id_number,
					       h.agency_id          AS agency_id,
					       eo.organization_name AS complaint_dept,
					       NULL                 AS court_id,
					       -- case number (other attrib - hold warant number)
					       EPIC.ef_get_attribute_value('HOLD WARRANT NUMBER',h.hold_id) AS case_no,
					       -- court name  (other attrib - hold court)
					       EPIC.ef_get_attribute_value('HOLD COURT',h.hold_id) AS court_name,
					       NULL AS court_date,
					       NULL AS court_division,
					       NULL AS court_judge,
					       NULL AS start_date,
					       NULL AS final_release_date,
					       -- bond/fines  (other attrib - hold amount)
					       to_number(EPIC.ef_get_attribute_value('HOLD AMOUNT',h.hold_id)) AS amount,
					       'BOND' AS amount_type,
						   'H'    AS Trans_type,
					       3      AS sortorder,
					        --EPIC.mcmb_fnt_offenderidfrombk(b.booking_id)||' - '||h.hold_id,
					   	    decode(sign(instr(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id),'10%')+
					  					instr(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id),'10 %')+
					   					instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'10 PERCENT'))-
					   					(instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'NO 10')*100)-
					   					(instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'NO10')*100),
									  					1,'Y','N') AS reduceamount,
							NULL AS paidoutdate,
							NULL AS unpaidoutdate,
							NULL AS surcharge_amount,
							NULL AS charge_state
					FROM EPIC.eh_booking_holds h,
					     EPIC.eh_active_booking b,
					     EPIC.eh_entity_organization eo
					WHERE b.booking_id = h.booking_id
					  AND eo.entity_id = h.agency_id
					  AND b.booking_id = p_message);	
		return;

	end;
	--
	  
	--
	--	Procedure update JIL with PHOTO records for a given inmate
	--
	procedure jil_PHOTO(
		p_message       in  varchar2,
		p_offender_id   in  varchar2)
	is
	begin 
		-- copy the data from OT to JIL
		logit('JIL PHOTO');
		return;

	end;
	--
	
	--
	--	Procedure update JIL with RELEASE records for a given inmate
	--
	procedure jil_release(
		p_message       in  varchar2,
		p_offender_id   in  varchar2)
	is
	begin 
		-- remove the data from JIL
		logit('JIL release');
		delete from MT_JIL_CHARGE@Link_IVR  where ENTITY_ID_FK = p_message;
		delete from MT_JIL_VISITOR@Link_IVR where ENTITY_ID_FK = p_message;
		delete from MT_JIL_ALIAS@Link_IVR   where ENTITY_ID_FK = p_message;
		delete from MT_JIL_INMATE@Link_IVR  where ENTITY_ID_PK = p_message;
		
		commit;
		
		return;

	end;
	--
	
	--
	--	Procedure to run a centeral processing of alerts.  
	--  Get first request
	--  open connection to dblink database
	--  Make updates where needed
	--  Update sync table
	--  Get next row.  When completed all exit....
	--  close dblink.
	--    
	
	procedure jil_process_alert (
		p_module		in  varchar2, 
		p_which_alert	in  varchar2, 
		p_message       in  varchar2)
	is

	cursor jil_process_requests is
		select JIL_SYNC_ID, OFFENDER_ID, ENTITY_ID, BOOKING_ID, ALERT_TYPE 
		from MACOMB.MT_JIL_SYNC_LIST 
		where PROCESS_STATUS = 'I' 
		  and COMPLETE is null 
		order by DATETIME;
		
	v_JIL_SYNC_ID		MACOMB.MT_JIL_SYNC_LIST.JIL_SYNC_ID%type; 
	v_OFFENDER_ID		MACOMB.MT_JIL_SYNC_LIST.OFFENDER_ID%type; 
	v_ENTITY_ID			MACOMB.MT_JIL_SYNC_LIST.ENTITY_ID%type;
	v_BOOKING_ID		MACOMB.MT_JIL_SYNC_LIST.BOOKING_ID%type;
	v_ALERT_TYPE		MACOMB.MT_JIL_SYNC_LIST.ALERT_TYPE%type;
	
	begin 
		-- copy the data from OT to JIL
		logit('JIL central processing');
		--  Get first request
		  -- open cursor     
			open jil_process_requests;
			fetch jil_process_requests into v_JIL_SYNC_ID, v_OFFENDER_ID, v_ENTITY_ID, v_BOOKING_ID, v_ALERT_TYPE;
			if jil_process_requests%notfound then  
			    -- nothing to process
				close jil_process_requests;				
				return;
			else   
  		        -- create dblink
				begin 
				--create database link Link_IVR connect to IVR identified by IVR01 using 'IntTempdb';

				-- this needs some work on processing the cursor
				
				while jil_process_requests%found  loop
					-- update sync process status to 'P' 
					update MACOMB.MT_JIL_SYNC_LIST
					set PROCESS_STATUS = 'P'
					where JIL_SYNC_ID = v_JIL_SYNC_ID;
					commit;
					
					-- update/insert based on alert_type
					IF v_ALERT_TYPE =  	 cs_JIL_ALIAS_alert	  then 
					   -- use  v_ENTITY_ID, v_OFFENDER_ID
					   mpk_jil.jil_alias(v_ENTITY_ID, v_OFFENDER_ID);
					elsif v_ALERT_TYPE = cs_JIL_INMATE_alert  then 
						-- use v_ENTITY_ID, v_OFFENDER_ID
						mpk_jil.jil_inmate(v_ENTITY_ID, v_OFFENDER_ID);
					elsif v_ALERT_TYPE = cs_JIL_CHARGE_alert  then 
						-- use v_BOOKING_ID, v_OFFENDER_ID
						mpk_jil.jil_charge(v_BOOKING_ID, v_OFFENDER_ID);
					elsif v_ALERT_TYPE = cs_JIL_VISITOR_alert then
						-- use v_ENTITY_ID, v_OFFENDER_ID  
						mpk_jil.jil_visitor(v_ENTITY_ID, v_OFFENDER_ID);
					elsif v_ALERT_TYPE = cs_JIL_BANNED_alert  then
						-- Just bring them all Macomb does not really use this yet	
						mpk_jil.jil_banned();
					elsif v_ALERT_TYPE = cs_JIL_RELEASE_alert then 
						-- use v_ENTITY_ID and V_BOOKING_ID to delete all data
						mpk_jil.jil_release(v_ENTITY_ID, v_OFFENDER_ID);
					elsif v_ALERT_TYPE = cs_JIL_PHOTO_alert	  then 
						mpk_jil.jil_photo(v_ENTITY_ID, v_OFFENDER_ID);
					end if;
					
					-- update sync process status to 'C' and complete to 1
					update MACOMB.MT_JIL_SYNC_LIST
					set (PROCESS_STATUS, COMPLETE)  = (select 'C', '1' from dual) 
					where JIL_SYNC_ID = v_JIL_SYNC_ID;
					
					commit;
					
				end loop;    
				-- close dblink
				--DROP database link Link_IVR ;
				end;
			end if;
		close jil_process_requests;
		
		
		return;

	end;
	--	
-----------------------------------
--PUBLIC PROCEDURES and FUNCTIONS--
-----------------------------------
	--
	--
	--	procedure to initialize the "config.inf" file for the TCP/IP file transfer process
	--
	--
	procedure init
	is
		--
		cs_mod					constant varchar2(255) := 'init';
		--
		v_config_data			varchar2(32767);
		v_eoln					varchar2(2);
		--
	begin
		logit('JIL init');
		return;
	end;
	--      
	
	--
	--
	--	procedure to register the alerts to watch for
	--
	--
	procedure register
	is
		--
		cs_mod					constant varchar2(255) := 'jil$register';
		--
	
	begin	
		--
		--	register alert
		--
		dbms_alert.register(mpk_jil.cs_JIL_ALIAS_alert);
		dbms_alert.register(mpk_jil.cs_JIL_INMATE_alert);
		dbms_alert.register(mpk_jil.cs_JIL_CHARGE_alert);
		dbms_alert.register(mpk_jil.cs_JIL_VISITOR_alert);
		dbms_alert.register(mpk_jil.cs_JIL_BANNED_alert);
		dbms_alert.register(mpk_jil.cs_JIL_RELEASE_alert);
		dbms_alert.register(mpk_jil.cs_JIL_PHOTO_alert);
		--
		--	register for termination alert
		--
		dbms_alert.register(mpk_jil.cs_stop_alert);
		dbms_alert.register(mpk_jil.cs_stop_JIL_alert); 
		commit work;

	end;
	--                             
	
	--
	--
	--	procedure to un register alerts
	--
	--
	procedure unregister
	is
		--
		cs_mod					constant varchar2(255) := 'jil$unregister';
		--
	
	begin	
		--
		--	register alert
		--  
		mpk_jil.signal(mpk_jil.cs_stop_JIL_alert, null);
		dbms_alert.remove(mpk_jil.cs_JIL_ALIAS_alert);
		dbms_alert.remove(mpk_jil.cs_JIL_INMATE_alert);
		dbms_alert.remove(mpk_jil.cs_JIL_CHARGE_alert);
		dbms_alert.remove(mpk_jil.cs_JIL_VISITOR_alert);
		dbms_alert.remove(mpk_jil.cs_JIL_BANNED_alert);
		dbms_alert.remove(mpk_jil.cs_JIL_RELEASE_alert);
		dbms_alert.remove(mpk_jil.cs_JIL_PHOTO_alert);
		--
		--	register for termination alert
		--
		dbms_alert.remove(mpk_jil.cs_stop_alert);
		dbms_alert.remove(mpk_jil.cs_stop_JIL_alert); 
		commit work;

	end;
	--                             

	--
	--
	--	procedure to wait for an alert and process it
	--
	--
	procedure waitany                                                                                    
	is
		v_module				varchar2(64);

		v_which_alert			varchar2(30);
		v_message				varchar2(32767);
		v_status				integer;
		v_timeout				number;
		v_error_count			integer := 0;
		v_debug					boolean;
		
		p_result				epic.epic_col_types.number_9%type;
		p_result_msg			epic.epic_col_types.varchar_255%type;
		v_temp					epic.epic_configuration.config_value%type;
        v_jobno					number;
		--
		--	cursor to read from the transaction table
		--
		--cursor cur_process is
		--	select * from macomb.mt_jil_alertmessage
		--	where module_id = v_module
		--	order by process_id;
	
	begin
		--
		--	main loop - wait for alert or termination signal
		--
		while true
		loop
			--
			--	trap errors here if possible
			--
			begin
				--
				--	wait for an alert
				--
				v_timeout := 3;	--	wake up each hour, anyway... 3600
				dbms_alert.waitany(v_which_alert,
	                    v_message,
	                    v_status,
	                    v_timeout);
	            --
	            --	first, check if alert and terminate message
	            --
	            if v_status = 0 then  --real alert  1 is a timeout.
	            	logit(v_which_alert);
	            	if v_which_alert = cs_stop_alert or v_which_alert = cs_stop_JIL_alert then
	            		--
	            		--	received termination message, log and end
	            		--
	            		logit('JIL Alert process terminated normally at ' || sysdate);
	            		unregister();
	            		return;
	            	end if; 
	            else
					-- close the alert process
            		logit('JIL Alert process terminated normally at ' || sysdate);
            		unregister();
            		return;
	            end if;
				--
				--	ok, either alert or timeout - don't care which, process anyway
				--
				if v_debug then
					if v_status = 0 then
						logit('JIL got alert');
					else
						logit('JIL got timeout');
					end if;
				end if;
				-- Insert into table MT_JIL_sync_list 
				-- this way if the alert is missed it will still be cared for
				insert into MT_JIL_sync_list 
				(jil_sync_id, offender_id, entity_id, booking_id, alert_type, 
				 process_status, complete, Datetime )
				select EPIC.epic_ids.new_epic_id,
				        id.offender_id,
				        id.entity_id,
				        b.booking_id,
				        v_which_alert,
				        'I',      -- Initialized (other statuses P - processing, C - completed, X - process by another request)
				        NULL,
				        sysdate
				from   EPIC.EH_OFFENDER_IDS id,
				       EPIC.EH_BOOKING b 
				where b.entity_id = id.entity_id
				  and id.entity_id = v_message; 
				commit;
				--
				--	check if any records in table to process
				--
					-- create job to process the record  
					-- v_message contains the epic_id (booking_id, entity_id, or charge_id)
					-- v_module deals with the task at hand         
				if v_debug = true then
					logit(v_which_alert|| ' - '||v_message|| ' in '||v_module);
				end if;
				mpk_jil.jil_process_alert(v_module, v_which_alert, v_message);
				
				/*
				if v_which_alert = mpk_jil.cs_JIL_ALIAS_alert then
					v_module := 'JIL ALIAS';
					mpk_jil.jil_alias(v_module, v_which_alert, v_message);
				elsIF v_which_alert = mpk_jil.cs_JIL_INMATE_alert then
					v_module := 'JIL INMATE';
					mpk_jil.jil_inmate(v_module, v_which_alert, v_message);
				elsIF v_which_alert = mpk_jil.cs_JIL_CHARGE_alert then
					v_module := 'JIL CHARGE';  
					mpk_jil.jil_charge(v_module, v_which_alert, v_message);
				elsIF v_which_alert = mpk_jil.cs_JIL_VISITOR_alert then
					v_module := 'JIL VISITOR';  
					mpk_jil.jil_visitor(v_module, v_which_alert, v_message); 
				elsIF v_which_alert = mpk_jil.cs_JIL_BANNED_alert then
					v_module := 'JIL BANNED';  
					mpk_jil.jil_banned(v_module, v_which_alert, v_message); 
				elsIF v_which_alert = mpk_jil.cs_JIL_RELEASE_alert then
					v_module := 'JIL RELEASE';   
					mpk_jil.jil_release(v_module, v_which_alert, v_message); 
				else 
					v_module := 'JIL UN-REGISTERED ALERT';
				end if;
	
				if v_debug = true then
					logit('*' || v_module || '*');
				end if;
	            */

			exception
				when others then
					--	log error and continue - if error count exceeds 100, bail
					epic.EP_LOG_INFO(
						mpk_jil.cs_JIL_module,	--	P_MODULE_ID,
						'E',							--	P_LOGTYPE,
						-1,								--	P_ACTION_BY,
						substr(sqlerrm || ' - ' || cs_mod, 1, 2000)	--	P_TEXT
						);
					v_error_count := v_error_count + 1;
					if v_error_count > 100 then
						logit('JIL Alert process terminated abnormally at ' || sysdate);
						return;
					end if;
			end;
		end loop;
	
	end;	
	
	procedure signal(
		p_alert				in		varchar2,
		p_message			in		epic.epic_col_types.varchar_255%type)
		-- p_alert - is the message type
		-- p_message - the key data to be moved.
	is
	begin
		DBMS_ALERT.SIGNAL(p_alert, p_message);	
		COMMIT WORK;
	end; 
	
	procedure regwaitany
	is 
	begin
		mpk_jil.register;
		mpk_jil.waitany;
	end;	
end MPK_JIL;
/
