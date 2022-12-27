CREATE OR REPLACE
package body      MPK_mjrs_Batch_Processing is
/*	Purpose:		MJRS - Process for running daily imports from OT into MJRS.
	Process:		Get the data from yesterday and process the records as imports to mjrs.
					
	Author:			Joe McBratnie
	
	Change Log:		Changed By	  Date Modified		Change Made
					------------  -------------		---------------------------------
					J. MCBRATNIE  	10/30/08		Created 

*/ 	


	--
	cs_mod							constant varchar2(255) := 'MJRS BATCH 1.0';
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
	gv_debug						boolean := true;
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
		if upper(substr(v_debug, 1, 1)) = 'Y' then
			gv_debug := true;
		else
			gv_debug := false;
		end if;
		--
		--	get interface enabled flag
		--
		v_enabled := upper(substr(v_enabled_value, 1, 1));
		if v_enabled not in ('Y','N') then
			raise_application_error(-20001, 'MJRS BATCH Enabled value must be "Y" or "N" [' || v_enabled_value || ']');
		end if;
		--
		--	return values
		--
		p_enabled := v_enabled;
	end;
    --
    
   	--
	--
	--	function for new batch id number
	--
	--
	FUNCTION Get_New_Batch
	 RETURN NUMBER AS
	
	/*
		Purpose:		MJRS - Create a new batch for importing data
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/  
	v_batch_id number;
	
	BEGIN
	    
		INSERT 
		  INTO OFFTRK_IMPORT_BACTHES
	           (batch_id, IMPORT_DATE, TRANSACTIONS, charges,inmate)
	    VALUES
	           (import_batches.nextval,
	            sysdate,
	            0,
	            0,
	            0 
	           );
	
		select import_batches.currval into v_batch_id from dual;
	  
	  RETURN v_batch_id;  
	END Get_New_Batch;
    --
    
  	--
	--
	--	function to get rent by offendertrak status code
	--
	--
    --
	FUNCTION Get_Rent
	( p_code_custody_status IN VARCHAR2,
	  p_number_of_days      IN number
	) RETURN NUMBER AS
	
	/*
		Purpose:		MJRS - Calculate the rent based on status
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/  
	v_rent number;
	BEGIN
	    BEGIN
			SELECT DAILY_RATE 
			  INTO v_rent
		      FROM CHARGE_TYPE
		     WHERE p_code_custody_status = OFFTRK_CODE 
		       AND IS_ACTIVE = 'yes';
		       
		   EXCEPTION
		    	when NO_DATA_FOUND then
		              v_rent := 0;
		END;			
	  RETURN nvl(v_rent*p_number_of_days,0);  
	END Get_Rent;    
   	--
	--
	--	function to get rent by trans_code
	--
	--
	FUNCTION Get_Rent_trans_code
	( p_TRANSACTION_CODE IN VARCHAR2,
	  p_number_of_days      IN number
	) RETURN NUMBER AS
	
	/*
		Purpose:		MJRS - Calculate the rent based on status
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/  
	v_rent number;
	BEGIN
	    BEGIN
			SELECT DAILY_RATE 
			  INTO v_rent
		      FROM CHARGE_TYPE
		     WHERE p_TRANSACTION_CODE = TRANSACTION_CODE 
		       AND IS_ACTIVE = 'yes'
		       AND rownum = 1;
		       
		   EXCEPTION
		    	when NO_DATA_FOUND then
		              v_rent := 0;
		END;			
	  RETURN nvl(v_rent*p_number_of_days,0);  
	END Get_Rent_trans_code;

	--
	
  	--
	--
	--	function to get rent by offendertrak status code
	--
	--
	FUNCTION Get_Transaction_Code
	( p_code_custody_status IN VARCHAR2
	) RETURN varchar2 AS
	
	/*
		Purpose:		MJRS - Find the transaction code
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/  
	v_trans varchar2(15);
	BEGIN 
		
		--dbms_output.put_line('trans code based on :'||p_code_custody_status);
	    BEGIN
			SELECT TRANSACTION_CODE 
			  INTO v_trans
		      FROM CHARGE_TYPE
		     WHERE p_code_custody_status = OFFTRK_CODE 
		       AND IS_ACTIVE = 'yes';
	     EXCEPTION
		   	  WHEN NO_DATA_FOUND THEN
		              v_trans := '-'||p_code_custody_status; 
	   END;
				
	  RETURN v_trans;  
	END Get_Transaction_Code;
    --
     
   	--
	--
	--	function to tell if inmate is sentenced
	--
	--
	FUNCTION is_sentenced
	( p_booking_id          IN VARCHAR2
	) RETURN varchar2 AS
	
	/*
		Purpose:		MJRS - Calculate the offense date
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/  
	v_sentenced varchar2(3);
	BEGIN
	    BEGIN
			SELECT DECODE(count(*),0,'NO','YES') 
			INTO v_sentenced
			FROM epic.eh_charge
			WHERE booking_id = p_booking_id
			  AND NOT sentence_id IS NULL;
	   EXCEPTION
		    	when NO_DATA_FOUND then
		              v_sentenced := 'NO';
		END;			
	  RETURN v_sentenced;  
	END is_sentenced;
    --
    
   	--
	--
	--	function if newly sentenced charges
	--
	--
    FUNCTION new_sentence
	(p_entity_id	in		EPIC.eh_booking.entity_id%type)   
	
	 /*	
		System: 		Macomb MJRS
		Purpose:		Returns Y if inmate an is newly sentenced.
		                
		Author:			Joe McBratnie
		
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/01/08		Created 
						
						
	*/       


	RETURN VARCHAR2 AS
	
	vActive VARCHAR2(1);
	  
	BEGIN          
		vActive := 'N';
	    BEGIN
			select 'Y' into vActive 
			from epic.eh_active_booking ab,
			     epic.eh_charge c,
			     epic.eh_Sentence s,
			     OFFTRK_IMPORT_BACTHES OTB
			where ab.booking_id = c.booking_id
			  and ab.entity_id = p_entity_id
			  and c.sentence_id = s.sentence_id
			  and epic.ef_epic_date_to_date(s.DATE_ENTERED) between OTB.Import_date --sysdate-1 -- last batch date from mjrs tables
			                                                    and sysdate;
	    EXCEPTION
	    	when NO_DATA_FOUND then
				vActive := 'N';
	    	when OTHERS then
				vActive := 'N';
		END;    		
				
	RETURN vActive;
	END;
    --
  
   	--
	--
	--	procedure to inc the batch number
	--
	--
	procedure INC_Batch  ( p_batch_id IN VARCHAR2)
	
	/*
		Purpose:		MJRS - Create a new batch for importing data
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/ 
	IS  
	v_status varchar2(3);
	v_trans number;
	
	BEGIN   
		UPDATE OFFTRK_IMPORT_BACTHES o
	       SET (TRANSACTIONS) = (select (transactions+1) from OFFTRK_IMPORT_BACTHES o2 where o.batch_id = o2.batch_id)
	    where batch_id = p_batch_id;
	    commit;
	END INC_Batch;
    --
    
   	--
	--
	--	procedure to inc the inmates batch number
	--
	--
	procedure INC_inmates_Batch  ( p_batch_id IN VARCHAR2)
	
	/*
		Purpose:		MJRS - Create a new batch for importing data
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/ 
	IS  
	v_status varchar2(3);
	v_trans number;
	
	BEGIN   
		UPDATE OFFTRK_IMPORT_BACTHES o
	       SET (INMATE) = (select (INMATE+1) from OFFTRK_IMPORT_BACTHES o2 where o.batch_id = o2.batch_id)
	    where batch_id = p_batch_id;
	    commit;
	END INC_inmates_Batch;
    --
    
   	--
	--
	--	procedure to inc the charges batch number
	--
	--
	procedure INC_charges_Batch  ( p_batch_id IN VARCHAR2)
	
	/*
		Purpose:		MJRS - Create a new batch for importing data
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     10/16/08        Created 
						                  
	*/ 
	IS  
	v_status varchar2(3);
	v_trans number;
	
	BEGIN   
		UPDATE OFFTRK_IMPORT_BACTHES o
	       SET (CHARGES) = (select (CHARGES+1) from OFFTRK_IMPORT_BACTHES o2 where o.batch_id = o2.batch_id)
	    where batch_id = p_batch_id;
	    commit;
	END INC_charges_Batch;
	--
	
--------------------------------------------------
--LOCAL PROCEDURES and FUNCTIONS to do the work --
--------------------------------------------------
	--
	--	Procedure add inmate to log
	--
	PROCEDURE MP_mjrs_inmate_insert_log 
	     (
			p_batch_id          IN      NUMBER,
			p_offender_id       IN		VARCHAR2,
			p_user_id           IN      INTEGER,		
			p_Status			   OUT	VARCHAR2
		 )
			
	IS
	/*	
		Purpose:		insert offendertrak inmate into mjrs log
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 09/29/08		Created 
						J. McBratnie 10/01/08       Updated error trapping and DOB function call
	                    S. Dunn      10/03/08       Changed Mail Status to Mail Status Id
	                                                Change p_status to varchar2 
	                    J. McBratnie 10/16/08       Added code for OFFTRK_IMPORT_INMATE_LOG
	                    J. McBratnie 10/21/08       added batch id           
	*/  
	v_inc_trans varchar2(3);
	
	begin
	    p_Status := 'TRUE';
	   
		BEGIN
	    	insert into OFFTRK_IMPORT_INMATE_LOG (batch_id, OFFENDER_ID, NAME_FIRST, NAME_FAMILY, NAME_OTHER, STREET, CITY_TOWN_LOCALE,
											STATE_PROVINCE_REGION, POSTAL_CODE, PHONE_NUMBER, ALTERNATIVE_PHONE_NUMBER,  
	                						SOCIAL_SECURITY_NUMBER, DRIVERS_LICENSE_NUMBER, MAIL_STATUS, DATE_OF_BIRTH) 
			 select p_batch_id,
			        id.offender_id as OFFENDER_ID,
					pi.NAME_FIRST as NAME_FIRST,
					pi.NAME_FAMILY as NAME_FAMILY,
					pi.NAME_OTHER as NAME_OTHER,
					ad.street_number || ' ' || ad.street_name || ' ' || ad.flat_no_or_floor_level as STREET,
					ad.city_town_locale as CITY_TOWN_LOCALE,
					ad.state_province_region as STATE_PROVINCE_REGION,
					ad.postal_code as POSTAL_CODE,
					replace(replace(replace(replace(
					   replace(macomb.mcmb_fnt_phone_per_address(id.entity_id, ad.address_id),'-',''),' ',''),'.',''),'(',''),')','') as PHONE_NUMBER,
					replace(replace(
					   replace(macomb.MF_EC_Area(id.entity_id)||macomb.MF_EC_PhNumber(id.entity_id),'-',''),' ',''),'.','') as ALTERNATIVE_PHONE_NUMBER,
					pi.social_security_number as SOCIAL_SECURITY_NUMBER,
					ol.drivers_license_number as DRIVERS_LICENSE_NUMBER,
	    			(select mail_status_id from MAIL_STATUS where mail_status_desc = 'Valid Address') as MAIL_STATUS, 
			        MACOMB.mcmb_fnt_DOB(id.entity_id) as DATE_OF_BIRTH
			from    epic.EH_PERSON_IDENTITY pi 
			             left outer join EPIC.eh_operators_license ol on pi.IDENTITY_ID = ol.IDENTITY_ID,
			        epic.eh_offender_ids id,
			        EPIC.eh_address ad
			where   id.entity_id = pi.entity_id
			  and   macomb.mf_jil_master_alias(id.entity_id, pi.IDENTITY_ID) =1
			  and   ad.entity_id = id.entity_id
			  and   ad.primary_flag  = 'Y' 
			  and   ad.entity_id = id.entity_id
			  and   ad.primary_flag  = 'Y' 
			  and   id.offender_id = p_offender_id;	
			
			COMMIT;	
		END;
			
	end;
	--	
    
	--
	--	Procedure add inmate Statement
	--
	PROCEDURE MP_mjrs_inmate_STMT_insert 
	     (
			p_batch_id          IN      NUMBER,
			p_offender_id       IN      VARCHAR2,
			p_Status              OUT   VARCHAR2
		 )
			
	IS
	/*	
		Purpose:		insert offendertrak inmate into mjrs
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 09/29/08		Created 
						J. McBratnie 10/01/08       Updated error trapping and DOB function call
	                    S. Dunn      10/03/08       Changed Mail Status to Mail Status Id
	                                                Change p_status to varchar2 
	                    J. McBratnie 10/16/08       Added code for OFFTRK_IMPORT_INMATE_LOG
	                    J. McBratnie 10/21/08       added batch id           
	*/  
	v_inc_trans varchar2(3);
	
	begin
	    p_Status := 'TRUE';
	   
	   IF (p_Status = 'TRUE') THEN
		 	-- inmates_stmt_info table setup
			BEGIN
				INSERT INTO INMATES_STMT_INFO
					(OFFENDER_ID, 
					 OVERRIDE_MONTHLY_AMT_DUE, 
					 OVERRIDE_CURRENT_AMT_DUE, 
					 LAST_PAYMENT_DATE, 
					 LAST_PAYMENT_AMT, 
					 LAST_STMT_MONTHLY_AMT_DUE,
					 LAST_STMT_CURRENT_AMT_DUE
					)
				VALUES
					(p_offender_id,
					 0.00,
					 0.00,
					 NULL,
					 NULL,
					 NULL,
					 NULL
					);  
			EXCEPTION 
				WHEN DUP_VAL_ON_INDEX THEN
		                      p_Status := 'FALSE';
			END;
		END IF;		
		commit;
	    --dbms_output.put_line('end of insert inmate');
	
		/*p_Status := TRUE;*/
			
	end;
	--
	
	--
	--	Procedure add inmate
	--
	PROCEDURE MP_mjrs_inmate_insert 
	     (
			p_batch_id			IN		number,
			p_offender_id       IN		VARCHAR2,
			p_user_id           IN      INTEGER,		
			p_Status			   OUT	VARCHAR2
		 )
			
	IS
	/*	
		Purpose:		insert offendertrak inmate into mjrs
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 09/29/08		Created 
						J. McBratnie 10/01/08       Updated error trapping and DOB function call
	                    S. Dunn      10/03/08       Changed Mail Status to Mail Status Id
	                                                Change p_status to varchar2 
	                    J. McBratnie 10/16/08       Added code for OFFTRK_IMPORT_INMATE_LOG
	                    J. McBratnie 10/21/08       added batch id           
	*/  
	v_inc_trans varchar2(3);
	
	begin
	    p_Status := 'TRUE';
	   
	    -- inmates
	    begin 
	    	insert into inmates (OFFENDER_ID, NAME_FIRST, NAME_FAMILY, NAME_OTHER, STREET, CITY_TOWN_LOCALE,
			STATE_PROVINCE_REGION, POSTAL_CODE, PHONE_NUMBER, ALTERNATIVE_PHONE_NUMBER,  
	                SOCIAL_SECURITY_NUMBER, DRIVERS_LICENSE_NUMBER, MODIFIED_BY, MODIFIED_DATE, ACCOUNT_STATUS_ID, MAIL_STATUS_ID, 
	                IS_LEGAL_JUDGMENT, IS_COLLECTIONS, IS_LEGACY_DATA, IS_LEGACY_CORRECTED, DATE_OF_BIRTH) 
			 select id.offender_id as OFFENDER_ID,
					pi.NAME_FIRST as NAME_FIRST,
					pi.NAME_FAMILY as NAME_FAMILY,
					pi.NAME_OTHER as NAME_OTHER,
					ad.street_number || ' ' || ad.street_name || ' ' || ad.flat_no_or_floor_level as STREET,
					ad.city_town_locale as CITY_TOWN_LOCALE,
					ad.state_province_region as STATE_PROVINCE_REGION,
					ad.postal_code as POSTAL_CODE,
					replace(replace(replace(replace(
					   replace(macomb.mcmb_fnt_phone_per_address(id.entity_id, ad.address_id),'-',''),' ',''),'.',''),'(',''),')','') as PHONE_NUMBER,
					replace(replace(
					   replace(macomb.MF_EC_Area(id.entity_id)||macomb.MF_EC_PhNumber(id.entity_id),'-',''),' ',''),'.','') as ALTERNATIVE_PHONE_NUMBER,
					pi.social_security_number as SOCIAL_SECURITY_NUMBER,
					ol.drivers_license_number as DRIVERS_LICENSE_NUMBER,
	                                p_user_id as MODIFIED_BY,  
					sysdate as MODIFIED_DATE,          
					(select account_status_id from ACCOUNT_STATUS_TYPES where account_status_desc = 'Active') as ACCOUNT_STATUS_ID,
	                                (select mail_status_id from MAIL_STATUS where mail_status_desc = 'Valid Address') as MAIL_STATUS, 
					'no' as IS_LEGAL_JUDGMENT, 
					'no' as IS_COLLECTIONS, 
					'no' as IS_LEGACY_DATA, 
					'no' as IS_LEGACY_CORRECTED,
			        MACOMB.mcmb_fnt_DOB(id.entity_id) as DATE_OF_BIRTH
			from    epic.EH_PERSON_IDENTITY pi 
			             left outer join EPIC.eh_operators_license ol on pi.IDENTITY_ID = ol.IDENTITY_ID,
			        epic.eh_offender_ids id,
			        EPIC.eh_address ad
			where   id.entity_id = pi.entity_id
			  and   macomb.mf_jil_master_alias(id.entity_id, pi.IDENTITY_ID) =1
			  and   ad.entity_id = id.entity_id
			  and   ad.primary_flag  = 'Y' 
			  and   ad.entity_id = id.entity_id
			  and   ad.primary_flag  = 'Y' 
			  and   id.offender_id = p_offender_id;
		EXCEPTION 
			  WHEN DUP_VAL_ON_INDEX THEN
				p_Status := 'FALSE'; 
		end; 
		commit;
		
		MP_mjrs_inmate_insert_log(p_batch_id,
		                          p_offender_id,
		                          p_user_id,
		                          p_Status
		                         );
		MP_mjrs_inmate_STMT_insert(p_batch_id,
								   p_offender_id,
		                           p_Status);
			
	end;
	--	
 
  	--
	--
	--	Procedure add charge/status
	--
	PROCEDURE mjrs_charge_add 
	     (
			 p_batch_id          IN      number,
			 p_offender_id       IN		VARCHAR2,
			 p_booking_id        IN      VARCHAR2,
			 p_custody_status_id IN      VARCHAR2,
	         p_status_start		IN		DATE,
	         p_status_end		IN		DATE,
			 p_Status			   OUT	VARCHAR2
		 )
	
	IS
/*		
		Purpose:		insert offendertrak charge/status into mjrs
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/14/08		Created  
						J. McBratnie 10/27/08		Update parameter list and function to fix bug 
						                            and reduce processing tim
	                  
*/	

  
	v_charge_id            number;
	v_booking_offense_date  date;
	v_is_sentenced          varchar2(3);
	BEGIN
	    p_Status := 'TRUE';
		-- set the max charge_id for reference later.  
	 	BEGIN
			SELECT max(charge_id) 
			  INTO v_charge_id 
			  FROM TRANSACTION_LOG 
			 WHERE offender_id = p_offender_id
		  GROUP BY offender_id;
		EXCEPTION when no_data_found then
			v_charge_id := 0;
		END; 
		
	   INSERT INTO CHARGES
	   (OFFENDER_ID, CHARGE_ID, TRANSACTION_CODE, BOOKING_DATE, 
	    OFFTRK_DAYS_IN, DAYS_IN, BATCH_ID, PROJ_RELEASE_DATE, 
	    STATUS_START_DATE, BOOKING_ID, custody_status_id,
	    IS_CASH_SETTLEMENT, IS_WORK_RELEASE, MODIFIED_BY, MODIFIED_DATE, AGING, WAS_STMT_SENT
	   )
		(SELECT distinct p_offender_id AS offender_id,
			   (v_charge_id + 1) AS charge_id, 
			   Mf_Get_Transaction_Code(code_custody_status) AS Transaction_code,
			   mf_Get_offense_date(booking_id) AS book_date, -- also called charged booked
			   floor(sysdate - p_status_start) AS offtrk_days_in, -- should this be projected days???
			   floor(sysdate - p_status_start) AS days_in,        -- should this be projected days???
	     	   p_batch_id,                       
			   p_status_end, --epic.ef_epic_date_to_date(epic.epp_booking_dates.final_release_date(bcs.booking_id)) AS proj_release_date,
			   p_status_start,  --epic.ef_epic_date_to_date(bcs.date_start) AS status_start_date,
			   p_booking_id AS booking_id,
			   p_custody_status_id,
			   'no',
			   'no',
			   0, -- User ID
			   sysdate,
			   0,
			   'no'
		FROM   epic.eh_booking_custody_status bcs
		WHERE 'Y' in (select decode(count(*),0,'N','Y')
				from epic.eh_charge
				where booking_id = bcs.booking_id) 
		  AND bcs.booking_id = p_booking_id
		  AND bcs.custody_status_id = p_custody_status_id )
	    ORDER BY 4 asc; 
	
		commit;
	
		INC_charges_Batch(p_batch_id);	
	END;        
	--	




	--
	--	Procedure add chrage/status log
	--
	PROCEDURE MP_mjrs_charge_insert_log 
	     (
			p_batch_id          IN      number,
			p_offender_id        IN      VARCHAR2,
			p_charge_id         IN      number
		 )
			
	IS
	/*	
		Purpose:		insert offendertrak charge/status into mjrs batch log
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/17/08		Created 
	                  
	*/  
	v_inc_trans varchar2(3);
	
	
	BEGIN
		--insert into OFFTRK_IMPORT_CHARGE_LOG
		--dbms_output.put_line('Insert charge/status....');
	
		INSERT INTO OFFTRK_IMPORT_CHARGE_LOG 
		SELECT p_batch_id, OFFENDER_ID, CHARGE_ID, TRANSACTIONLOG_SEQ.nextval, sysdate, TRANSACTION_CODE, 
		       BOOKING_DATE, END_DATE, OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
		       PROJ_RELEASE_DATE, STATUS_START_DATE, STATUS_END_DATE, 
		       BOOKING_ID, IS_CASH_SETTLEMENT, IS_WORK_RELEASE
		 FROM CHARGES
		WHERE offender_id = p_offender_id
		  AND charge_id = p_charge_id;
		
		
		COMMIT;
		 --    dbms_output.put_line('charge_status');
	
	END;
	--	

	--
	--	Procedure release old charge/status
	--
	PROCEDURE MP_mjrs_charge_release 
	     (
			p_batch_id          IN      number,
 			p_offender_id       IN		VARCHAR2,
 			p_booking_id		IN		VARCHAR2,
 			p_custody_status_id IN      VARCHAR2,
	        p_status_start		IN		DATE,
			p_Status			   OUT	VARCHAR2
		 )
	
	IS
	/*	
		Purpose:		close charge/status in mjrs
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/14/08		Created  
						J. McBratnie 10/27/08		Update parameter list and function to fix bug 
						                            and reduce processing tim
	                  
	*/  
	v_charge_id         number;
	 vt_charge_id 		NUMBER;
	 v_trancode 		varchar2(20);
	 v_amt	     		number;
	 v_end_date 		date;
	 
	BEGIN
	    p_Status := 'TRUE';
		-- set the max charge_id for reference later.  
	 	BEGIN
			SELECT max(charge_id) 
			  INTO v_charge_id 
			  FROM charges 
			 WHERE offender_id = p_offender_id
		  GROUP BY offender_id;
		EXCEPTION when no_data_found then
			v_charge_id := 0;
		END;   
		
		--IF v_charge_id > 0 THEN -- update old charge/status
	 
			BEGIN
				UPDATE charges 
				  SET (STATUS_END_DATE, OFFTRK_DAYS_IN, days_in, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
				        MODIFIED_BY
				      ) = 
					(SELECT --p_status_start,
					     p_status_start,
						 floor(p_status_start-status_start_date) as offdays_in,
		                 decode(ADJUSTED_DAYS_IN_BY,0,floor(p_status_start-status_start_date), DAYS_IN) as days_in,
		                 -- function to calc rent
		                 MF_Get_Rent_trans_code(TRANSACTION_CODE ,
		                             floor(p_status_start-status_start_date)
		                            ) as original_charge_amt,
		                 decode(IS_CASH_SETTLEMENT,'no',
		                                           decode(IS_WORK_RELEASE,'no',mf_Get_Rent_trans_code(TRANSACTION_CODE ,
		                                                                                              floor(p_status_start-status_start_date)
		                                                                                             ), ADJUSTED_CHARGE_AMT
		                                                  ), ADJUSTED_CHARGE_AMT) as ADJUSTED_CHARGE_AMT,
						 --p_status_start AS STATUS_END_DATE,
						 0 -- User ID
					 FROM charges --epic.eh_booking_custody_status bcs
					 WHERE offender_id = p_offender_id 
					   and charge_id = v_charge_id --booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
					) 
				WHERE offender_id = p_offender_id
				  AND charge_id = v_charge_id
				  AND status_end_date IS NULL;  
			EXCEPTION WHEN no_data_found THEN
				 p_Status := 'FALSE';
			END;
			IF p_Status = 'TRUE' THEN			  
				MP_mjrs_charge_insert_log(p_batch_id, p_offender_id, v_charge_id);
			END IF;
	        --dbms_output.put_line('release charge ' || p_status_start|| ' offender ' ||p_offender_id|| ' charge_id '|| v_charge_id);
		commit;   
		
		-- get data for sues transaction log
		SELECT TRANSACTION_CODE, ADJUSTED_CHARGE_AMT, STATUS_END_DATE
		  INTO v_trancode,       v_amt,               v_end_date
		  FROM CHARGES 
		 WHERE OFFENDER_ID = p_offender_id
		   AND charge_id = v_charge_id;

		-- post to sue's log   
 	    --    dbms_output.put_line('post trans ' || p_offender_id|| ' ' ||v_charge_id|| ' trans '|| v_trancode ||
 	     --                       ' amount '||v_amt ||' on ' ||v_end_date);
		MP_MJRS_POST_TRANSACTION
			( p_offender_id, -- IN STRING
			  v_charge_id, -- ChargeId IN NUMBER
			  v_trancode,  -- TranCode IN STRING
			  v_amt,       -- TranAmt IN NUMBER
			  v_end_date,  -- RunDate IN DATE
			  0,         -- RunBy IN NUMBER
			  null,        -- PymtTypeId IN NUMBER
			  null         -- RefNum IN STRING
	        );
	END;    
	--	

	--
	--	Procedure release inmate
	--
	PROCEDURE MP_mjrs_release_inmate 
	     (
			p_batch_id          IN      number,
 			p_offender_id       IN		VARCHAR2,
 			p_booking_id		IN		VARCHAR2,
 			p_custody_status_id IN      VARCHAR2,
	        p_status_start		IN		DATE, 
	        p_STATUS_END		IN		DATE,
			p_Status			   OUT	VARCHAR2
		 )
	
	IS
	/*	
		Purpose:		close charge/status for release in mjrs
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/14/08		Created  
						J. McBratnie 10/27/08		Update parameter list and function to fix bug 
						                            and reduce processing tim
	                  
	*/  
	v_charge_id         number;
	v_error_trp         EXCEPTION;
	 vt_charge_id 		NUMBER;
	 v_trancode 		varchar2(20);
	 v_amt	     		number;
	 v_end_date 		date;
	
	BEGIN
	    p_Status := 'TRUE';
		-- set the max charge_id for reference later.  
	 	BEGIN
			SELECT max(charge_id) 
			  INTO v_charge_id 
			  FROM charges 
			 WHERE offender_id = p_offender_id
		  GROUP BY offender_id;
		EXCEPTION when no_data_found then
			v_charge_id := 0;
		END;   
		vt_charge_id := v_charge_id;
		
		BEGIN
			UPDATE charges 
			  SET (END_DATE, OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
			       proj_release_date, STATUS_END_DATE, MODIFIED_BY
			      ) = 
				(SELECT --p_status_start,
				     p_STATUS_END, 
				     -- finalize days in
				     floor(p_STATUS_END - status_start_date),
				     decode(ADJUSTED_DAYS_IN_BY,0,floor(p_STATUS_END - status_start_date),days_in),
					 -- function to calc rent
	                 MF_Get_Rent_trans_code(TRANSACTION_CODE ,
	                             floor(p_STATUS_END-status_start_date)
	                            ) as original_charge_amt,
	                 decode(IS_CASH_SETTLEMENT,'no',
	                                           decode(IS_WORK_RELEASE,'no',mf_Get_Rent_trans_code(TRANSACTION_CODE ,
	                                                                                              floor(p_STATUS_END-status_start_date)
	                                                                                             ), ADJUSTED_CHARGE_AMT
	                                                  ), ADJUSTED_CHARGE_AMT) as ADJUSTED_CHARGE_AMT,
	                 p_STATUS_END,
	                 p_STATUS_END,
					 0 -- User ID
				 FROM charges --epic.eh_booking_custody_status bcs
				 WHERE offender_id = p_offender_id 
				   and charge_id = v_charge_id --booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
				   and custody_status_id = p_custody_status_id
				) 
			WHERE offender_id = p_offender_id
			  AND charge_id = v_charge_id
			  AND custody_status_id = p_custody_status_id
			  AND end_date IS NULL;  

			IF SQL%NOTFOUND THEN
     			RAISE v_error_trp; 
     			DBMS_OUTPUT.PUT_LINE('update failed');
   			END IF;
			COMMIT;
		EXCEPTION WHEN v_error_trp THEN 
		
				--DBMS_OUTPUT.PUT_LINE ('failed to release inmate '|| 
				--                       p_offender_id ||' '||v_charge_id||' ' || 
				--                       p_STATUS_END|| ' ' || p_custody_status_id );
				-- this condition should never happen accept for first run.
				-- The inmate is released and no charge and sentenced records have been established.
  				p_Status := 'FALSE';
  			
		END; 

		IF p_Status = 'TRUE' THEN			  
			MP_mjrs_charge_insert_log(p_batch_id, p_offender_id, v_charge_id);
		END IF;

		--DBMS_OUTPUT.PUT_LINE ('Get Sues data '|| 
		--		                       p_offender_id ||' '||v_charge_id||' '||vt_charge_id||' ' ||p_custody_status_id );
		-- get data for Sue transaction log
		SELECT TRANSACTION_CODE, ADJUSTED_CHARGE_AMT, STATUS_END_DATE
		  INTO v_trancode,       v_amt,               v_end_date
		  FROM CHARGES 
		 WHERE OFFENDER_ID = p_offender_id
		   AND charge_id = vt_charge_id;
		
		-- post data to her log   
  	    --    dbms_output.put_line('post trans ' || p_offender_id|| ' ' ||v_charge_id|| ' trans '|| v_trancode ||
 	    --                        ' amount '||v_amt ||' on ' ||v_end_date);
		MP_MJRS_POST_TRANSACTION
			( p_offender_id, -- IN STRING
			  v_charge_id, -- ChargeId IN NUMBER
			  v_trancode,  -- TranCode IN STRING
			  v_amt,       -- TranAmt IN NUMBER
			  v_end_date,  -- RunDate IN DATE
			  0,         -- RunBy IN NUMBER
			  null,        -- PymtTypeId IN NUMBER
			  null         -- RefNum IN STRING
	        );	
	END;        
	--	
-----------------------------------
--PUBLIC PROCEDURES and FUNCTIONS--
-----------------------------------
	--
	--
	--	procedure to initate a batch process run
	--
	--
	PROCEDURE MP_mjrs_Batch_Run 
	     (
			p_run_date          IN      Date
		 )
			
	IS
	/*	
		Purpose:		Build and process a batch of changes from OT
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/17/08		Created 
	                  
	*/ 
	v_last_run_date    date;
	v_run_date         date;
	v_batch_id         number;  
	v_status           varchar2(20);
	v_inmate_exists    varchar2(3);
	v_flag_open_charge varchar2(3);
	vr_OFFENDER_ID		varchar2(16);
	vr_BOOKING_ID       varchar2(16);
	vr_CUSTODY_STATUS_ID varchar2(16);
	vr_STATUS            varchar2(20);
	vr_ORDER_BY          number(8,0);
	vr_CUSTODY_STATUS    number(8,0);
	vr_STATUS_DATE       date;
	vr_STATUS_END        date;
	
	CURSOR process_list 
		IS
		   -- Add any inmates that are not in the system from previous runs.
		   -- Normally, this should be 0 row for this part of the union
			SELECT distinct id.offender_id AS OFFENDER_ID,
			                b.booking_id   AS BOOKING_ID,
				            custody_status_id as CUSTODY_STATUS_ID,
			                'NEW MISSING'  AS STATUS,
			                0              AS ORDER_BY,
			                code_custody_status  AS CUSTODY_STATUS,
			                epic.ef_epic_date_to_date(date_start)  AS STATUS_DATE,
			                null                 AS STATUS_END
			FROM   epic.eh_sentence s,
			       epic.eh_charge c,
			       epic.eh_active_booking b,
			       epic.eh_booking_custody_status bcs,
			       epic.eh_offender_ids id
			WHERE  b.booking_id = c.booking_id
			  AND  b.booking_id = bcs.booking_id
			  AND  c.sentence_id = s.sentence_id
			  AND  c.sentence_id is not null
			  AND  b.entity_id = id.entity_id
			  AND  not bcs.code_custody_status in ('12')
			  AND  NOT EXISTS (select 1
					           from inmates i
					           where id.offender_id = i.offender_id)
			UNION  -- create a new inmate
				SELECT distinct id.offender_id AS OFFENDER_ID,
				                b.booking_id   AS BOOKING_ID,
				                custody_status_id,
				                'NEW SENTENCE' AS STATUS,
				                1              AS ORDER_BY,
				                code_custody_status  AS CUSTODY_STATUS,
				                epic.ef_epic_date_to_date(date_start)  AS STATUS_DATE,
				                null                AS STATUS_END
					FROM   epic.eh_sentence s,
					       epic.eh_charge c,
					       epic.eh_active_booking b,
					       epic.eh_booking_custody_status bcs,
					       epic.eh_offender_ids id
					WHERE  b.booking_id = c.booking_id
					  AND  b.booking_id = bcs.booking_id
 					  AND  not bcs.code_custody_status in ('12')
					  AND  c.sentence_id = s.sentence_id
					  AND  b.entity_id = id.entity_id
					  AND  epic.ef_epic_date_to_date(date_entered) BETWEEN to_date('04/01/2007 10:05:51')
					  											       AND sysdate
			UNION  -- newly release inmates
				SELECT distinct id.offender_id,
				                b.booking_id ,
				                custody_status_id,
				                'RELEASE INMATE',
				                3,
				                code_custody_status,
				                epic.ef_epic_date_to_date(date_start),
				                epic.ef_epic_date_to_date(ACTUAL_RELEASE)
				FROM   epic.eh_release r,
				       epic.eh_booking b,
				       epic.eh_booking_custody_status bcs,
				       epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.booking_id = r.booking_id
				  AND  b.booking_id = bcs.booking_id				  
				  AND  b.entity_id = id.entity_id
				  AND  b.booking_id = c.booking_id
				  AND  not bcs.code_custody_status in ('12')
				  AND  c.sentence_id is not null
				  AND  epic.ef_epic_date_to_date(r.actual_release) BETWEEN to_date('04/01/2007 10:05:51')
				                                                       AND sysdate
			UNION  -- newly status changes
				SELECT distinct id.offender_id,
				                bcs.booking_id ,
				                custody_status_id,
				                'STATUS UPDATE',
				                2 ,
				                code_custody_status,
				                epic.ef_epic_date_to_date(date_start)  AS STATUS_DATE,
				                null AS STATUS_END
				FROM   epic.eh_booking_custody_status bcs,
				       epic.eh_active_booking b,
					   epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.entity_id = id.entity_id
				  AND  b.booking_id = bcs.booking_id
				  AND  not bcs.code_custody_status in ('12')
				  AND  b.booking_id = c.booking_id
				  AND  c.sentence_id is not null        -- at least one charge sentenced
				  --AND  bcs.code_custody_status <>'3'    -- PAROLEE  4208
				  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN to_date('04/01/2007 10:05:51')
				                                                      AND sysdate
				order by 1,4;                                                       ---    need to add booking_custody_Status_id to this update....
	
	
	BEGIN               
		-- get the last run date to use in cursor above.
		SELECT max(import_date) 
		  INTO v_last_run_date
		  FROM OFFTRK_IMPORT_BACTHES;
		  
	     v_batch_id := Get_New_Batch();
	     
		-- add new inmates (newly sentenced)
		-- update inmates
		-- release inmates               
	   	FOR records in process_list
		LOOP                    
			IF   vr_OFFENDER_ID is null THEN
				vr_OFFENDER_ID		:= records.OFFENDER_ID;
				vr_BOOKING_ID       := records.BOOKING_ID;
				vr_CUSTODY_STATUS_ID := records.CUSTODY_STATUS_ID;
				vr_STATUS            := records.STATUS;
				vr_ORDER_BY          := records.ORDER_BY;
				vr_CUSTODY_STATUS    := records.CUSTODY_STATUS;
				vr_STATUS_DATE       := records.STATUS_DATE;
				vr_STATUS_END        := records.STATUS_END; 
            END IF;


			IF (records.offender_id <> vr_OFFENDER_ID) THEN   -- VR loop
				IF (vr_STATUS = 'RELEASE INMATE' ) THEN
			     	/*MP_mjrs_charge_release ( v_batch_id, 
			     							 vr_offender_id,
			     							 vr_booking_id,
			     							 vr_custody_status_id,
			     							 vr_STATUS_DATE, 
			     							 v_status);
						IF v_status = 'FALSE' THEN
							DBMS_OUTPUT.PUT_LINE('RELEASE INMATE charge release failed'|| v_batch_id ||' '||
					                        vr_offender_id ||' '||
					                        vr_booking_id ||' '||
					                        vr_custody_status_id);
						END IF;
                      */
					dbms_output.put_line('   release inmate '||v_status);
	   				MP_mjrs_release_inmate(	v_batch_id,
						                        vr_offender_id,
						                        vr_booking_id,
						                        vr_custody_status_id,
						                        vr_STATUS_DATE, -- start
						                        vr_STATUS_END,
						                        v_status); 
					-- Make a second attempt to release the inmate.  This should only happen 
					-- when charge we never entered.  For example: during system conversion...						                        
					IF v_status = 'FALSE' THEN
						DBMS_OUTPUT.PUT_LINE('RELEASE INMATE failed'|| v_batch_id ||' '||
				                        vr_offender_id ||' '||
				                        vr_booking_id ||' '||
				                        vr_custody_status_id);
					END IF;				
				END IF;             ---------EO VR loop
           END IF;
			-- check for inmate in system already, should be for all but new sentenced inmates 
			v_status := 'TRUE';
			BEGIN
				SELECT 'YES' INTO v_inmate_exists FROM INMATES i WHERE i.offender_id = records.offender_id;  
			EXCEPTION WHEN no_data_found THEN
				-- Inmate not in system, insert please.
				v_inmate_exists := 'NO';
			END;
			--v_flag
 			BEGIN
				SELECT 'YES' INTO v_flag_open_charge 
				  FROM charges c 
				 WHERE c.offender_id = records.offender_id 
				   AND STATUS_END_DATE IS NULL;  
			EXCEPTION WHEN no_data_found THEN
				-- Inmate not in system, insert please.
				v_flag_open_charge := 'NO';
			END;
			-- new inmate needed???
			IF (records.STATUS = 'NEW SENTENCE' or records.STATUS = 'NEW MISSING') THEN  
				-- Insert demographics
				-- update any previous status for this inmates booking
				v_status := 'no';
	 			--dbms_output.put_line('new sent'); 
	 			IF v_inmate_exists = 'NO' THEN
					MP_mjrs_inmate_insert(v_batch_id,records.offender_id,0,v_status);
				ELSE
					MP_mjrs_inmate_update(v_batch_id,records.offender_id,0,records.CUSTODY_STATUS,v_status);  -- needs to be created
				END IF; 
	            INC_inmates_Batch(v_batch_id);
			END IF;	
   			-- release old charge/status
			IF v_flag_open_charge = 'YES' THEN
   			   	MP_mjrs_charge_release ( v_batch_id, records.offender_id,records.booking_id,records.custody_status_id,records.STATUS_DATE, v_status);
			END IF;		
			-- create new charge/status
			mjrs_charge_add(   v_batch_id,
		                          records.offender_id,
		                          records.booking_id,
		                          records.custody_status_id,
		                          records.STATUS_DATE, -- start
		                          records.STATUS_END,
		                          v_status);
			IF v_status = 'FALSE' THEN
				DBMS_OUTPUT.PUT_LINE('Status update failed'|| v_batch_id ||' '||
		                        records.offender_id ||' '||
		                        records.booking_id ||' '||
		                        records.custody_status_id);
			END IF;
	 		INC_charges_Batch(v_batch_id);
			 	
		 	-- Add to log also. 
 	 		commit;             

			IF v_status = 'FALSE' THEN
				DBMS_OUTPUT.PUT_LINE('Status update failed'|| v_batch_id ||' '||
		                        records.offender_id ||' '||
		                        records.booking_id ||' '||
		                        records.custody_status_id);
			END IF;
	 		inc_batch(v_batch_id);
			vr_OFFENDER_ID		:= records.OFFENDER_ID;
			vr_BOOKING_ID       := records.BOOKING_ID;
			vr_CUSTODY_STATUS_ID := records.CUSTODY_STATUS_ID;
			vr_STATUS            := records.STATUS;
			vr_ORDER_BY          := records.ORDER_BY;
			vr_CUSTODY_STATUS    := records.CUSTODY_STATUS;
			vr_STATUS_DATE       := records.STATUS_DATE;
			vr_STATUS_END        := records.STATUS_END; 
 	 		
		END LOOP;

		-- could be one left in memory.  Try here.
		IF (vr_STATUS = 'RELEASE INMATE' ) THEN
			--dbms_output.put_line('   release inmate '||v_status);
  				MP_mjrs_release_inmate(	v_batch_id,
				                        vr_offender_id,
				                        vr_booking_id,
				                        vr_custody_status_id,
				                        vr_STATUS_DATE, -- start
				                        vr_STATUS_END,
				                        v_status); 
			-- Make a second attempt to release the inmate.  This should only happen 
			-- when charge we never entered.  For example: during system conversion...						                        
			IF v_status = 'FALSE' THEN
				DBMS_OUTPUT.PUT_LINE('RELEASE INMATE failed'|| v_batch_id ||' '||
		                        vr_offender_id ||' '||
		                        vr_booking_id ||' '||
		                        vr_custody_status_id);
			END IF;				

		END IF;
	END;
	--      
	
end MPK_mjrs_Batch_Processing;
/
