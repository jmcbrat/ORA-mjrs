CREATE OR REPLACE
package body      MPK_mjrs_Batch_Processing is
/*	Purpose:		MJRS - Process for running daily imports from OT into MJRS.
	Process:		Get the data from yesterday and process the records as imports to mjrs.
					
	Author:			Joe McBratnie
	
	Change Log:		Changed By	  Date Modified		Change Made
					------------  -------------		---------------------------------
					J. MCBRATNIE  	10/30/08		Created 
					J. Mcbratnie	11/12/08		Updated the code to correct a few bugs and added
					                                logic to supress debugging details.
					J. McBratnie    12/18/08		Commented the project and arranged fn, procs
													for turn over to Kelly. 

*/ 	
/*
Turn over documentation.


Just a few lines down you will see two gloabal varibles that all debugging to be done on loads.
gv_debug - boolean for if you want to be in debug mode.  Below that is gv_debug_inmate is allows
you to watch (dbms_output) only one of the inmates that you are looking for details on.  
Filtering like this will make the prcess easier.

The first 5 functions and procedures are part of the stanrdard interface package and are not 
used but ok to keep around.  I planned on making use of them later as testing was wrapping down.  
Given we cut testing short they were not installed yet.

Also, some of the functions this process uses is located outside this package.  I normally 
develop them in the Procedure, function area and them move them into the package.  Then remove 
them from the instance of the db.  Again this was cut short.  

The package header has functions listed that should not be.  They are exposed because of the 
manual updates needed post go live.  They should be hidden later to ensure they are not called 
externally.

At the bottom in the main processing routine and the base query I am grabbing OT data from.  
I broke the data down to events.  Events are New Inmate, New Missing, Status change, release 
inmate, work release inmate.  

New Inmate and New missing basically add the inmate into inmates table.

Status Change is for a charge-status that is new. To have a new one you have to prime the pump 
and create an initial one in charge_detail.  Status change is anything except work release and 
release.  When a release or work release status comes, the rows in charge detail are summed and 
added into charges table.  

Work release end dates the current charges.  Creates a charge_detail row for the work release and 
then nulls the days and money.  

Release is like work release.  It endates the charge_Detail records and finalizes the charges 
record.  Work release and release are the only two ways to release an inmate.

Every time a status of any time comes in we have to endate the current charges.  This is handled 
in the MP_MJRS_Enddate_charge_detail routine.  

Tables:
OFFTRK_IMPORT_LOG         -- Created by manish.  Not complete enough.  Can be removed.
OFFTRK_IMPORT_BATCHES     -- logs the statistics of a batch load.
OFFTRK_IMPORT_CHARGE_LOG  -- logs the charge-status that are updated in the system.
OFFTRK_IMPORT_INMATE_LOG  -- logs the inmates that are added in this system and what batch 
CHARGE_TYPE               -- lookup table that translates from OT admin status to a charge_type

CHARGE_DETAIL             -- all transactions un summeriezd, inmate, booking, custody_status_id 
                          -- on the OT side.  Offender_id, charge_id on the MJRS (charges) 
CHARGES                   -- summary data because Lori does not want to see all transactions.
INMATES                   -- When an inmate is sentenced they are added her so Lori can see them
                          -- and start to barter with them before the release.
INMATES_ADDRESS_HISTORY   -- the current address is moved here when the record is added.
INMATES_STMT_INFO         -- a base row is created here for Sue's process  

Still to be done:
  non critial (show stoppers) that are required

  better transaction logging.
  better backout processing.

  minor corrections in process of bring data from OT to mjrs
  
*/

	--
	cs_mod							constant varchar2(255) := 'MJRS BATCH 1.1';
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
	gv_debug_inmate					varchar2(8) := '107867';
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
	--	function for current charge_id number
	--
	--
	FUNCTION Get_Max_Charge_ID 
	( p_offender_id IN VARCHAR2)
	 RETURN NUMBER AS
	
	/*
		Purpose:		MJRS - Get the max. charge Id.
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     12/11/08        Created 
						                  
	*/  
	v_charge_id number;
	
	BEGIN
		BEGIN
			SELECT nvl(max(charge_id),0)
			  INTO v_charge_id
			  FROM charges
			 WHERE offender_id = p_offender_id;	    
		EXCEPTION
		    	when NO_DATA_FOUND then
		              v_charge_id := 0; 
		END;
	  
		RETURN v_charge_id;  
	END Get_Max_Charge_ID;
    --

  	--
	--
	--	function for current charge_detail_id number
	--
	--
	FUNCTION Get_Max_Charge_detail_ID 
	( p_booking_id IN VARCHAR2)
	 RETURN NUMBER AS
	
	/*
		Purpose:		MJRS - Get the max. charge Id.
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     12/11/08        Created 
						                  
	*/  
	v_charge_id number;
	
	BEGIN
		BEGIN
			SELECT nvl(max(charge_detail_id),0)
			  INTO v_charge_id
			  FROM charge_detail
			 WHERE booking_id = p_booking_id;	    
		EXCEPTION
		    	when NO_DATA_FOUND then
		              v_charge_id := 0; 
		END;
				  
		RETURN v_charge_id;  
	END Get_Max_Charge_detail_ID;
    --


  	--
	--
	--	function for current charges amount number
	--
	--
	FUNCTION Get_charges_amt 
	( p_offender_id IN VARCHAR2,
	  p_charge_id IN number)
	 RETURN NUMBER AS
	
	/*
		Purpose:		MJRS - Get the amount from charges
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     12/11/08        Created 
						                  
	*/  
	v_amount number;
	
	BEGIN
		BEGIN
			SELECT NVL(ORIGINAL_CHARGE_AMT,0)
			  INTO v_amount
			  FROM charges
			 WHERE offender_id = p_offender_id
			   AND charge_id = p_charge_id;	
		EXCEPTION
		    	when NO_DATA_FOUND then
		              v_amount := 0; 
		END;
	  
		RETURN v_amount;  
	END Get_charges_amt;
    --


  	--
	--
	--	function for current transaction code
	--
	--
	FUNCTION Get_trans_code 
	( p_offender_id IN VARCHAR2,
	  p_charge_id IN number)
	 RETURN varchar2 AS
	
	/*
		Purpose:		MJRS - Get the transaction code from charges
						
		Author:			Joe McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
	                                ------------	 -------------	------------------------------------------
	                                J. McBratnie     12/11/08        Created 
						                  
	*/  
	v_trans varchar2(4);
	
	BEGIN
		BEGIN
			SELECT NVL(TRANSACTION_CODE,'0000')
			  INTO v_trans
			  FROM charges
			 WHERE offender_id = p_offender_id
			   AND charge_id = p_charge_id;	
		EXCEPTION
		    	when NO_DATA_FOUND then
		              v_trans := '0000';  
		END;
	  
		RETURN v_trans;  
	END Get_trans_code;
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
		  INTO OFFTRK_IMPORT_BATCHES
	           (batch_id, IMPORT_DATE, TRANSACTIONS, charges,inmate,trans_log_start,trans_log_end)
	    VALUES
	           (import_batches.nextval,
	            sysdate,
	            0,
	            0,
	            0,
	            TRANSACTIONLOG_SEQ.NEXTVAL,
	            null 
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
	FUNCTION To_Transaction_Code
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
		
		if gv_debug then
			dbms_output.put_line('trans code based on :'||p_code_custody_status);
		end if;
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
	END To_Transaction_Code;
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
			     OFFTRK_IMPORT_BATCHES OTB
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
		UPDATE OFFTRK_IMPORT_BATCHES o
	       SET (TRANSACTIONS) = (select (transactions+1) from OFFTRK_IMPORT_BATCHES o2 where o.batch_id = o2.batch_id)
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
		UPDATE OFFTRK_IMPORT_BATCHES o
	       SET (INMATE) = (select (INMATE+1) from OFFTRK_IMPORT_BATCHES o2 where o.batch_id = o2.batch_id)
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
		UPDATE OFFTRK_IMPORT_BATCHES o
	       SET (CHARGES) = (select (CHARGES+1) from OFFTRK_IMPORT_BATCHES o2 where o.batch_id = o2.batch_id)
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
			  and   ad.address_id = mf_address_id(id.entity_id)
			  and   id.offender_id = p_offender_id;	
			
			COMMIT;	
		END;
			
	end;
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
		if gv_debug then
			dbms_output.put_line('Insert charge/status....'||p_offender_id ||', '||p_charge_id);
		END IF;
		INSERT INTO OFFTRK_IMPORT_CHARGE_LOG 
		SELECT p_batch_id, OFFENDER_ID, CHARGE_ID, TRANSACTIONLOG_SEQ.currval, sysdate, TRANSACTION_CODE, 
		       BOOKING_DATE, END_DATE, OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
		       PROJ_RELEASE_DATE, STATUS_START_DATE, STATUS_END_DATE, 
		       BOOKING_ID, IS_CASH_SETTLEMENT, IS_WORK_RELEASE
		 FROM CHARGES
		WHERE offender_id = p_offender_id
		  AND charge_id = p_charge_id;
		
		
		COMMIT;  
 		if gv_debug then
			 dbms_output.put_line('charge_status');
	    end if;
	END;
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
		if gv_debug then
		    dbms_output.put_line('end of insert inmate');
		end if;	
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
					MACOMB.mcmb_fnt_drvlicense_primary(id.entity_id) as DRIVERS_LICENSE_NUMBER,
	                                p_user_id as MODIFIED_BY,  
					sysdate as MODIFIED_DATE,          
					(select account_status_id from ACCOUNT_STATUS_TYPES where account_status_desc = 'Inactive') as ACCOUNT_STATUS_ID,
	                                (select mail_status_id from MAIL_STATUS where mail_status_desc = 'Valid Address') as MAIL_STATUS, 
					'no' as IS_LEGAL_JUDGMENT, 
					'no' as IS_COLLECTIONS, 
					'no' as IS_LEGACY_DATA, 
					'no' as IS_LEGACY_CORRECTED,
			        MACOMB.mcmb_fnt_DOB(id.entity_id) as DATE_OF_BIRTH
			from    epic.EH_PERSON_IDENTITY pi, 
			             --left outer join EPIC.eh_operators_license ol on pi.IDENTITY_ID = ol.IDENTITY_ID,
			        epic.eh_offender_ids id,
			        EPIC.eh_address ad
			where   id.entity_id = pi.entity_id
			  and   macomb.mf_jil_master_alias(id.entity_id, pi.IDENTITY_ID) =1
			  and   ad.entity_id(+) = id.entity_id
			  and   ad.address_id(+) = mf_address_id(id.entity_id)
			  and   id.offender_id = p_offender_id;
		EXCEPTION 
			  WHEN DUP_VAL_ON_INDEX THEN
				p_Status := 'FALSE';  
				--dbms_output.put_line('insert inmate failed: ' || p_offender_id);	
				
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
	--	Procedure end date charge
	--
	PROCEDURE MP_MJRS_Enddate_charge_detail 
	     (
			p_offender_id       IN      varchar2,
			p_booking_id        IN      varchar2,
			p_status_end        IN      date,
	        p_charge_detail_id  IN 		number
		 )
	IS
	/*	
		Purpose:		Close down the open charge and return the max charge_id
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 11/18/08		Created  

	                  
	*/  
	v_dates_equal varchar2(1);
	v_start_date  date;
	
	BEGIN
		if gv_debug then
			DBMS_OUTPUT.PUT_LINE ('Enddate charge: '||p_booking_id||' ' ||p_status_end|| ' ' ||p_charge_detail_id);
		end if;	
	 	IF p_charge_detail_id > 0 THEN  -- must already have a record to end date it.
	 		-- compare the start date and end date if same then zero days/zero amount
	 		BEGIN
		 		SELECT distinct STATUS_START_DATE
		 		  INTO v_start_date 
				  FROM charge_detail --epic.eh_booking_custody_status bcs
				 WHERE booking_id = p_booking_id
				   AND charge_detail_id = p_charge_detail_id --booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
				   AND STATUS_END_DATE IS NULL;
		    EXCEPTION 
			    when TOO_MANY_ROWS then 
			    	DBMS_OUTPUT.PUT_LINE ('database has more than on open end date record for end charge');
				when NO_DATA_FOUND then 
				    v_start_date := null;
				when others then 
					DBMS_OUTPUT.PUT_LINE ('end charge other error exists');
			END; 
			IF NOT v_start_date is null THEN
				IF 	((p_status_end - v_start_date) = 0) THEN
					v_dates_equal := 'Y';
				ELSE
					v_dates_equal := 'N';
				END IF;
		 		-- end date the open charge detail record 
			if gv_debug = TRUE and gv_debug_inmate = p_offender_id THEN
				DBMS_OUTPUT.put_line('end: '||p_offender_id||' ' ||p_charge_detail_id||' ' ||v_dates_equal||' '||p_status_end);
			end if;
		 		 
				UPDATE charge_detail 
				   SET (OFFTRK_DAYS_IN, CHARGE_AMT, STATUS_END_DATE, MODIFIED_BY, MODIFIED_DATE) = 
					   (SELECT -- finalize days in
					           decode(p_status_end-1, status_start_date, 0, CEIL(p_status_end - status_start_date)) as days_in,
					           -- function to calc rent
		                       MF_Get_Rent_trans_code(TRANSACTION_CODE ,
		                                              decode(v_dates_equal,'N',CEIL(p_STATUS_END-status_start_date),0)) as charge_amt, 
				               decode(v_dates_equal,'N',p_status_end-1,p_status_end),
							   0 as User_ID,
							   sysdate
						 FROM  charge_detail --epic.eh_booking_custody_status bcs
						 WHERE booking_id = p_booking_id
						   AND charge_detail_id = p_charge_detail_id --booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
						) 
				WHERE booking_id = p_booking_id
				  AND charge_detail_id = p_charge_detail_id; 
			END IF;
		END IF; 
	
	END;	 
	--


  	--
	--
	--	Procedure add charge/status
	--
	PROCEDURE mjrs_charge_add 
	     (
			 p_batch_id          IN     number,
			 p_offender_id       IN		VARCHAR2,
			 p_booking_id        IN     VARCHAR2,
			 p_custody_status_id IN     VARCHAR2,
			 p_cust_status       IN     VARCHAR2,
	         p_status_start		 IN		DATE,
	         p_status_end		 IN		DATE,
	         p_charge_detail_id  IN     number,
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
						J. McBratnie 11/18/08       Updated for new specs
	                  
*/	

	v_charge_id             number;
	v_booking_offense_date  date;
	v_status_end            date;
	v_is_sentenced          varchar2(3); 
	
	BEGIN
	    p_Status := 'TRUE';
 		-- Make sure the status is set to inactive while houses.
       update inmates
       set ACCOUNT_STATUS_ID = (select account_status_id 
                                  from ACCOUNT_STATUS_TYPES 
                                 where account_status_desc = 'Inactive')
       where offender_id = p_offender_id;

		if gv_debug then
		 	 dbms_output.put_line('charge_detail = ' || p_booking_id ||' '||p_custody_status_id||' '||p_offender_id||' '||
		 	                      p_charge_detail_id ||' '|| p_batch_id||' '||p_status_end ||' '||p_status_start);
		end if;

			if gv_debug = TRUE and gv_debug_inmate = p_offender_id THEN
				DBMS_OUTPUT.put_line('Add '||p_offender_id||' ' ||p_charge_detail_id||' '||p_status_start ||' '||p_status_end);
			end if;
		-- update the charge_detail rocord
 	   INSERT INTO CHARGE_DETAIL
	   (OFFENDER_ID, CHARGE_detail_ID, TRANSACTION_CODE, BOOKING_DATE, 
	    OFFTRK_DAYS_IN, BATCH_ID, PROJ_RELEASE_DATE, 
	    STATUS_START_DATE, BOOKING_ID, custody_status_id,
	    IS_WORK_RELEASE, MODIFIED_BY, MODIFIED_DATE
	   )
		(SELECT distinct p_offender_id AS offender_id,
			   p_charge_detail_id + 1 AS charge_detail_id, 
			   Mf_Get_Transaction_Code(p_cust_status) AS Transaction_code,
			   mf_Get_offense_date(booking_id) AS book_date, -- also called charged booked
			   CEIL((epic.ef_epic_date_to_date(epic.epp_booking_dates.final_release_date(bcs.booking_id)) - p_status_start)) AS offtrk_days_in, -- should this be projected days???
			   p_batch_id,                       
			   epic.ef_epic_date_to_date(epic.epp_booking_dates.final_release_date(bcs.booking_id)) AS proj_release_date,
			   p_status_start,  --epic.ef_epic_date_to_date(bcs.date_start) AS status_start_date,
			   p_booking_id AS booking_id,
			   p_custody_status_id,
			   'no',
			   0 as User_ID,
			   sysdate
		FROM   epic.eh_booking_custody_status bcs
		WHERE 'Y' in ( select decode(count(*),0,'N','Y')
						 from epic.eh_charge
						where booking_id = bcs.booking_id) 
		  AND bcs.booking_id = p_booking_id
		  AND bcs.custody_status_id = p_custody_status_id )
	    ORDER BY 4 asc; 
	
	
		INC_charges_Batch(p_batch_id);	                 
		
		
		IF p_charge_detail_id = 0 THEN    -- The first record will create a charges record  update it later.
 			v_charge_id := Get_Max_Charge_ID(p_offender_id)+1;
			INSERT INTO charges
				(OFFENDER_ID, CHARGE_ID, TRANSACTION_CODE, BOOKING_DATE, END_DATE, 
				 OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
				 BATCH_ID, IS_CASH_SETTLEMENT, WAS_STMT_SENT, 
				 AGING, PROJ_RELEASE_DATE, STATUS_START_DATE, BOOKING_ID, MODIFIED_BY, 
				 MODIFIED_DATE, IS_WORK_RELEASE, CUSTODY_STATUS_ID)
			  	(SELECT OFFENDER_ID,v_charge_id, TRANSACTION_CODE, BOOKING_DATE, END_DATE, 
						OFFTRK_DAYS_IN, OFFTRK_DAYS_IN, CHARGE_AMT,CHARGE_AMT,
						BATCH_ID, 'no', 'no',
						0, PROJ_RELEASE_DATE, STATUS_START_DATE, BOOKING_ID, MODIFIED_BY, 
						MODIFIED_DATE, 'no',CUSTODY_STATUS_ID
				 FROM  charge_detail
				WHERE  booking_id = p_booking_id
				  AND  CHARGE_DETAIL_ID = p_charge_detail_id+1);
                    
               UPDATE charge_detail            -- add the charge_id to charge_detail record....
                  SET charge_id = v_charge_id
                WHERE booking_id = p_booking_id
                  AND CHARGE_DETAIL_ID = p_charge_detail_id+1;


		END IF;		
        COMMIT;
	END;        
	--	

	--
	--	Procedure release old charge/status        can be removed
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
	 v_status_end		date;
	 
	BEGIN
	    p_Status := 'TRUE';
		-- set the max charge_id for reference later.  
	 	BEGIN
			SELECT c.charge_detail_id, c.status_end_date
			INTO   v_charge_id, v_status_end
			FROM CHARGE_DETAIL c
			WHERE c.offender_id = p_offender_id
			  and c.booking_id = p_booking_id
			  AND c.charge_detail_id = ( SELECT MAX(c2.charge_detail_id)
										   FROM CHARGE_DETAIL c2
									      WHERE c2.offender_id = c.offender_id --'108121' --p_offender_id
									        AND c2.booking_id = c.booking_id
							  		   GROUP BY c2.offender_id );	 	
		EXCEPTION when no_data_found then
			v_charge_id := 0;
		END;   
		
		--IF v_charge_id > 0 THEN -- update old charge/status
	 
			BEGIN
				UPDATE CHARGE_DETAIL 
				  SET (STATUS_END_DATE, OFFTRK_DAYS_IN, CHARGE_AMT, MODIFIED_BY, MODIFIED_DATE
				      ) = 
					(SELECT --p_status_start,
					     p_status_start-1,
						 CEIL(p_status_start-status_start_date) as offdays_in,
		                 -- function to calc rent
		                 MF_Get_Rent_trans_code(TRANSACTION_CODE ,
		                             CEIL(p_status_start-1-status_start_date)) as original_charge_amt,
						 0 as User_ID,
						 sysdate
					 FROM charge_detail --epic.eh_booking_custody_status bcs
					 WHERE offender_id = p_offender_id 
					   and charge_detail_id = v_charge_id --booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
					) 
				WHERE offender_id = p_offender_id
				  AND charge_detail_id = v_charge_id
				  AND status_end_date IS NULL;  
			EXCEPTION WHEN no_data_found THEN
				 p_Status := 'FALSE';
			END;
			IF p_Status = 'TRUE' THEN			  
				MP_mjrs_charge_insert_log(p_batch_id, p_offender_id, v_charge_id);
			END IF;
			if gv_debug then
	        	dbms_output.put_line('release charge ' || p_status_start|| ' offender ' ||p_offender_id|| ' charge_id '|| v_charge_id);
			end if;
		commit;   
		
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
 			p_cust_status       IN      VARCHAR2,
	        p_status_start		IN		DATE, 
	        p_STATUS_END		IN		DATE,
	        p_charge_detail_id  IN      number,
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
	 v_trans_log        NUMBER;
	 v_trancode 		varchar2(20); 
	 v_workrelease      varchar2(1);
	 v_amt	     		number;
	 v_end_date 		date;
	 v_status_end		date;
     v_error            varchar2(1);
     v_status			varchar2(20);
	
	BEGIN
		if gv_debug then
	   		DBMS_OUTPUT.PUT_LINE ('release inmate: '||p_booking_id||' ' ||p_status_end|| ' ' ||p_charge_detail_id);
		end if;
    	/*	if not work release inmate
	    	       Update rent and closing dates
			All statuses are summed into one row in charges. 
			  Status is set to 'Active'
			Add transaction log entry
	   	*/	      
	   	
	   	-- Just double checking...  returns 'TRUE' or 'FALSE'
	    MP_mjrs_has_trans_code_status(p_offender_id, p_booking_id, '4201', p_status);   -- 4201 is work release
	        
	    	-- set inmate to get statements
		    BEGIN 
		    	IF p_status = 'FALSE' THEN                             -- Just in case it is work release
			         UPDATE inmates
			         SET ACCOUNT_STATUS_ID = (SELECT account_status_id FROM ACCOUNT_STATUS_TYPES WHERE account_status_desc = 'Active')
			         WHERE offender_id = p_offender_id;
		     	ELSE
			         UPDATE inmates
			         SET ACCOUNT_STATUS_ID = (SELECT account_status_id FROM ACCOUNT_STATUS_TYPES WHERE account_status_desc = 'Inactive')
			         WHERE offender_id = p_offender_id;   
			    END IF;
		    END;

			BEGIN   
			-- 
			    -- End date the final charges record 
				BEGIN             
			    	IF p_status = 'FALSE' THEN  -- NOT WORK RELEASE Therefore, all trustee, and regular type stays.
						-- get the max charge_id from charge_detail  
						vt_charge_id := Get_Max_Charge_ID(p_offender_id);  
  						v_charge_id := Get_Max_Charge_detail_ID(p_booking_id);  
 			if gv_debug = TRUE and gv_debug_inmate = p_offender_id THEN
				DBMS_OUTPUT.put_line('release '||p_offender_id||' ' ||vt_charge_id||' ' ||v_charge_id);
			end if;
						
						-- if records exist then update, else insert
						IF v_charge_id =0 THEN 
							-- new row from go live.
						    -- insert a charge_detail row 
			if gv_debug = TRUE and gv_debug_inmate = p_offender_id THEN
				DBMS_OUTPUT.put_line('add new ' || p_offender_id||' ' ||p_status_start||' ' ||p_STATUS_END);
			end if;
						    
							mjrs_charge_add(   p_batch_id,
							                   p_offender_id,
							                   p_booking_id,
							                   p_custody_status_id,
							                   p_cust_status,
							                   p_status_start, -- start
							                   p_STATUS_END,  -- charge_detail_id max value set above 
							                   p_charge_detail_id,
							                   v_status); 
							-- must update the newly created record to show closing date. 
					
							MP_MJRS_Enddate_charge_detail(p_offender_id, p_booking_id, p_STATUS_END, v_charge_id);  
 							
							
							COMMIT;							
							vt_charge_id := Get_Max_Charge_ID(p_offender_id);  
							v_charge_id := Get_Max_Charge_detail_ID(p_booking_id);  
 						ELSE
							--dbms_output.put_line(p_offender_id||' - '|| v_charge_id ||' ' ||p_status_end);
			if gv_debug = TRUE and gv_debug_inmate = p_offender_id THEN
				DBMS_OUTPUT.put_line('fix old ' || p_offender_id||' ' ||p_status_start||' ' ||p_STATUS_END||' '||v_charge_id||' '||vt_charge_id);
			end if;
 
								UPDATE charge_detail 
							   SET (END_DATE, OFFTRK_DAYS_IN, CHARGE_AMT, STATUS_END_DATE, MODIFIED_BY, MODIFIED_DATE) = 
								   (SELECT -- finalize days in
								           p_status_end, 
								           CEIL(p_status_end - status_start_date) as days_in,
								           -- function to calc rent
					                       MF_Get_Rent_trans_code(TRANSACTION_CODE ,
					                                              CEIL(p_STATUS_END-status_start_date)) as charge_amt, 
							               p_status_end,
										   0 as User_ID,
										   sysdate
									 FROM  charge_detail --epic.eh_booking_custody_status bcs
									 WHERE booking_id = p_booking_id
									   AND charge_detail_id = v_charge_id)
							  WHERE booking_id = p_booking_id
							    AND charge_detail_id = v_charge_id; --booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
									  
						END IF;
						
 						vt_charge_id := Get_Max_Charge_ID(p_offender_id);  
						v_trancode := To_Transaction_Code(p_cust_status);
						-- update charges open row with sum of charge_detail
 
						UPDATE charges
						   SET (adjusted_charge_amt, original_charge_amt, status_start_date, status_end_date  )   
						     = (SELECT SUM(adjusted_charge_amt), 
						               SUM(original_charge_amt), 
						               MIN(status_start_date), 
						               MAX(status_end_date) 
						          FROM CHARGE_detail
								 WHERE booking_id = p_booking_id
								   AND TRANSACTION_CODE = v_trancode
								   AND CHARGE_ID = vt_charge_id)  
						WHERE offender_id = p_offender_id
						  AND TRANSACTION_CODE = v_trancode
						  AND CHARGE_ID = vt_charge_id;
						  
						-- Now that we have to correct range of days, calc the days in....
						UPDATE charges
						   SET (END_DATE, OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT  )   
						     = (SELECT STATUS_END_DATE,
						     		   STATUS_END_DATE - STATUS_START_DATE,
						     		   STATUS_END_DATE - STATUS_START_DATE,
				                       MF_Get_Rent_trans_code(TRANSACTION_CODE ,
				                                              CEIL(STATUS_END_DATE-STATUS_START_DATE)) as org_charge_amt, 
				                       MF_Get_Rent_trans_code(TRANSACTION_CODE ,
				                                              CEIL(STATUS_END_DATE-STATUS_START_DATE)) as adj_charge_amt 
						          FROM CHARGES
								 WHERE offender_id = p_offender_id
								   AND TRANSACTION_CODE = v_trancode
								   AND charge_id = vt_charge_id)
						WHERE offender_id = p_offender_id
						  AND charge_id = vt_charge_id
						  AND TRANSACTION_CODE = v_trancode;						  
						
						-- add an entry for trans log 
						--dbms_output.put_line(p_offender_id||' cd_id '|| p_charge_detail_id||' cid '||vt_charge_id||' trans ' ||Get_trans_code(p_offender_id,vt_charge_id));
				
							MP_MJRS_POST_TRAN
								( p_offender_id, -- IN STRING
								  vt_charge_id, -- ChargeId IN NUMBER
								  Get_trans_code(p_offender_id,vt_charge_id),  -- TranCode IN STRING
								  Get_charges_amt(p_offender_id,vt_charge_id),       -- TranAmt IN NUMBER
								  sysdate,  -- RunDate IN DATE
								  0,         -- RunBy IN NUMBER
								  null,        -- PymtTypeId IN NUMBER
								  null         -- RefNum IN STRING
						        );							
					--No ELSE needed on this one.  If Work release do nothing on release....	
					END IF;
				END;	
		END;
	END;        
	--	


	--
	--	Procedure release inmate
	--
	PROCEDURE MP_mjrs_work_release_inmate 
	     (
			p_batch_id          IN      number,
 			p_offender_id       IN		VARCHAR2,
 			p_charge_detail_id	IN 		number,
 			p_booking_id		IN		VARCHAR2,
 			p_custody_status_id IN      VARCHAR2,
 			p_cust_status       IN      VARCHAR2,
	        p_status_start		IN		DATE, 
	        p_STATUS_END		IN		DATE,
			p_Status			   OUT	VARCHAR2
		 )

	IS
	/*	
		Purpose:		process work release records.
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 11/18/08		Created
	                  
	*/  

	v_charge_id         number; 
	v_charge_detail_id  number;
	v_error_trp         EXCEPTION;
	 vt_charge_id 		NUMBER;
	 v_trans_log        NUMBER;
	 v_trancode 		varchar2(20);
	 v_amt	     		number;
	 v_end_date 		date;
	 v_status_end		date;
	 v_trans_code       varchar2(4);
	 v_status           varchar2(20);

	
	BEGIN
	    p_Status := 'TRUE';  
		v_trans_code := To_Transaction_Code(p_cust_status);	-- get the trans code for use later.    
	     
	    -- Zero rent on previous charge/status (only in charges table, charge_detail will show the full rent)
	    -- close chrages row (enddate)  (set the work release flag on new record only)
         
         UPDATE inmates
            SET ACCOUNT_STATUS_ID = (SELECT account_status_id FROM ACCOUNT_STATUS_TYPES WHERE account_status_desc = 'Inactive')
          WHERE offender_id = p_offender_id;   

	    
	    -- update the charges record for this booking/inmate set the money and days
	                                      -- also end date the
	    v_charge_id := Get_Max_Charge_ID(p_offender_id); 
		UPDATE charges
		   SET (OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, IS_WORK_RELEASE, MODIFIED_BY, MODIFIED_DATE  )   
		     = (SELECT STATUS_END_DATE - STATUS_START_DATE,
		     		   STATUS_END_DATE - STATUS_START_DATE,
		     		   0,0, 'yes',0,sysdate
		          FROM CHARGES
				 WHERE offender_id = p_offender_id
				   AND charge_id = v_charge_id)
		WHERE offender_id = p_offender_id
		  AND charge_id = v_charge_id;  
		  
		-- Corrects a problem where we are adding a transaction to meet the normal reg inmate status preping.
		-- The orginial is not needed on the form of exit.
		MP_MJRS_DELETE_TRANSACTION(p_offender_id, v_charge_id);
		  			    
	    
	    -- insert a charge_detail row
		mjrs_charge_add(   p_batch_id,
		                   p_offender_id,
		                   p_booking_id,
		                   p_custody_status_id,
		                   p_cust_status,
		                   p_status_start, -- start
		                   p_STATUS_END,  -- charge_detail_id max value set above 
		                   p_charge_detail_id,
		                   v_status);

		v_charge_detail_id := Get_Max_Charge_detail_ID(p_booking_id);
		v_charge_id := Get_Max_Charge_ID(p_offender_id);
		
		-- make the new row into a work release row
		UPDATE charge_detail
		   SET (OFFTRK_DAYS_IN, CHARGE_AMT, IS_WORK_RELEASE, MODIFIED_BY, MODIFIED_DATE  )   
		     = (SELECT STATUS_END_DATE - STATUS_START_DATE,
		     		   0,'yes',0,sysdate
		          FROM CHARGE_DETAIL
				 WHERE offender_id = p_offender_id
				   AND CHARGE_DETAIL_ID = v_charge_detail_id)
		WHERE offender_id = p_offender_id
		  AND CHARGE_DETAIL_ID = v_charge_detail_id ;
		  
  	    -- insert a charges row
		INSERT INTO charges
			(OFFENDER_ID, CHARGE_ID, TRANSACTION_CODE, BOOKING_DATE, END_DATE, 
			 OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
			 BATCH_ID, IS_CASH_SETTLEMENT, WAS_STMT_SENT, 
			 AGING, PROJ_RELEASE_DATE, STATUS_START_DATE, BOOKING_ID, MODIFIED_BY, 
			 MODIFIED_DATE, IS_WORK_RELEASE, CUSTODY_STATUS_ID)
		 	(SELECT OFFENDER_ID,v_charge_id+1, TRANSACTION_CODE, BOOKING_DATE, END_DATE, 
					OFFTRK_DAYS_IN, OFFTRK_DAYS_IN, CHARGE_AMT,CHARGE_AMT,
					BATCH_ID, 'no', 'no',
					0, PROJ_RELEASE_DATE, STATUS_START_DATE, BOOKING_ID, MODIFIED_BY, 
					MODIFIED_DATE, 'yes',CUSTODY_STATUS_ID
			  FROM  charge_detail
			 WHERE  booking_id = p_booking_id
			   AND  CHARGE_DETAIL_ID = p_charge_detail_id+1);
                
           UPDATE charge_detail            -- add the charge_id to charge_detail record....
              SET charge_id = v_charge_id+1
            WHERE booking_id = p_booking_id
              AND CHARGE_DETAIL_ID = p_charge_detail_id+1;   
        COMMIT;
              
	    -- insert a tran log entry
			MP_MJRS_POST_TRAN
				( p_offender_id, -- IN STRING
				  Get_Max_Charge_ID(p_offender_id), -- ChargeId IN NUMBER
				  Get_trans_code(p_offender_id,Get_Max_Charge_ID(p_offender_id)),  -- TranCode IN STRING
				  Get_charges_amt(p_offender_id,Get_Max_Charge_ID(p_offender_id)),       -- TranAmt IN NUMBER
				  sysdate,  -- RunDate IN DATE
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
						J. McBratnie 11/18/08       Corrected a bug in the main query.   
	                  
	*/ 
	v_last_run_date      date;
	v_run_date           date;
	v_batch_id           number;  
	v_status             varchar2(20);
	v_status_end         date;
	v_charge_detail_id   number(38);
	v_inmate_exists      varchar2(3);
	v_flag_open_charge   varchar2(3);
	vr_OFFENDER_ID		 varchar2(16);
	vr_BOOKING_ID        varchar2(16);
	vr_CUSTODY_STATUS_ID varchar2(16);
	vr_STATUS            varchar2(20);
	vr_ORDER_BY          number(8,0);
	vr_CUSTODY_STATUS    number(8,0);
	vr_STATUS_DATE       date;
	vr_STATUS_END        date;
	v_has_work_release   varchar(1);
	v_cnt                number(8,0);
	
	CURSOR process_list 
		IS
		   -- Add any inmates that are not in the system from previous runs.
		   -- Normally, this should be 0 row for this part of the union
			SELECT distinct id.offender_id AS OFFENDER_ID,
			                b.booking_id   AS BOOKING_ID,
				            custody_status_id as CUSTODY_STATUS_ID,
			                'NEW MISSING'  AS STATUS,
			                0              AS ORDER_BY,
			                bcs.code_custody_status  AS CUSTODY_STATUS,
							to_Date(decode(epic.ef_epic_date_to_date(date_start),
							                                   null,
							                                   null,
							                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
			                null                 AS STATUS_END
			FROM   epic.eh_sentence s,
			       epic.eh_charge c,
			       epic.eh_booking b,
			       epic.eh_booking_custody_status bcs,
			       epic.eh_offender_ids id
			WHERE  b.booking_id = c.booking_id
			  AND  b.booking_id = bcs.booking_id
			  AND  c.sentence_id = s.sentence_id
			  AND  c.sentence_id is not null
			  AND  b.entity_id = id.entity_id
			  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
			  AND  NOT EXISTS (select 1
					           from inmates i
					           where id.offender_id = i.offender_id)
			UNION  -- create a new inmate
				SELECT distinct id.offender_id AS OFFENDER_ID,
				                b.booking_id   AS BOOKING_ID,
				                custody_status_id,
				                'NEW SENTENCE' AS STATUS,
				                1              AS ORDER_BY,
				                bcs.code_custody_status  AS CUSTODY_STATUS,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
				                null                AS STATUS_END
					FROM   epic.eh_sentence s,
					       epic.eh_charge c,
					       epic.eh_booking b,
					       epic.eh_booking_custody_status bcs,
					       epic.eh_offender_ids id
					WHERE  b.booking_id = c.booking_id
					  AND  b.booking_id = bcs.booking_id
 					  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
					  AND  c.sentence_id = s.sentence_id
					  AND  b.entity_id = id.entity_id
					  AND  epic.ef_epic_date_to_date(date_entered) BETWEEN sysdate - 25 --v_last_run_date
					  											       AND sysdate
			UNION  -- newly release inmates
				SELECT distinct id.offender_id,
				                b.booking_id ,
				                custody_status_id,
				                'RELEASE INMATE',
				                4,                    -- note was 3
				                bcs.code_custody_status,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
								to_Date(decode(epic.ef_epic_date_to_date(ACTUAL_RELEASE),null,null,to_char(epic.ef_epic_date_to_date(ACTUAL_RELEASE), 'mm/dd/yyyy')||' 23:59:59')) as status_end
				FROM   epic.eh_booking_custody_status bcs,
				       epic.eh_release r,
				       epic.eh_booking b,
				       epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.booking_id = r.booking_id
				  AND  b.entity_id = id.entity_id
				  AND  b.booking_id = c.booking_id
				  AND  b.booking_id = bcs.booking_id
				  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
				  AND  c.sentence_id is not null        -- at least one charge sentenced
				  AND  epic.ef_epic_date_to_date(r.actual_release) BETWEEN v_last_run_date
				                                                       AND sysdate
			UNION  -- new work releases (require special handling)
				SELECT distinct id.offender_id,
				                b.booking_id ,
				                custody_status_id,
				                'WORK RELEASE',
				                3,
				                code_custody_status,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
						       null as status_end
				FROM   epic.eh_booking b,
				       epic.eh_booking_custody_status bcs,
				       epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.booking_id = bcs.booking_id
				  AND  b.entity_id = id.entity_id
				  AND  b.booking_id = c.booking_id
				  AND  bcs.code_custody_status in ('5')    -- work release only.
				  AND  c.sentence_id is not null
				  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN  v_last_run_date
				                                                      AND sysdate
			UNION  -- newly status changes
				SELECT distinct id.offender_id,
				                bcs.booking_id ,
				                custody_status_id,
				                'STATUS UPDATE',
				                2 ,
				                bcs.code_custody_status,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
				                null AS STATUS_END
				FROM   epic.eh_booking_custody_status bcs,
				       epic.eh_booking b,
					   epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.entity_id = id.entity_id
				  AND  b.booking_id = bcs.booking_id
				  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
				  AND  b.booking_id = c.booking_id
				  AND  c.sentence_id is not null        -- at least one charge sentenced
				  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN  v_last_run_date
				                                                      AND sysdate
				order by 2,7,5;  -- was 1,4                                                      
	
	
	BEGIN               
		-- get the last run date to use in cursor above.
		SELECT max(import_date) 
		  INTO v_last_run_date
		  FROM OFFTRK_IMPORT_BATCHES;
		  
	     v_batch_id := Get_New_Batch();
	     v_charge_detail_id := 0;
	     COMMIT;
		-- add new inmates (newly sentenced)
		-- update inmates
		-- release inmates  
		v_cnt := 1;             
	   	FOR records in process_list
		LOOP    
	       -- if was (this booking) on work release skip DO NOT TOUCH per Lori
			BEGIN
				SELECT decode(lower(IS_WORK_RELEASE),'yes','Y','N')
				  INTO v_has_work_release 
				  FROM CHARGE_DETAIL
				 WHERE booking_id = records.booking_id
				   AND IS_WORK_RELEASE = 'yes';
		    EXCEPTION 
				when NO_DATA_FOUND then 
				    v_has_work_release := 'N';
				when others then 
					v_has_work_release := 'N';				
			END;  

			IF v_has_work_release = 'N' THEN
				-- locate previous record and update the end date 
				--    v_charge_detail_id are set in this procedure for use in the 
				--    main IF structure and all record adds and updates.
				--  if start and end dates are equal then make zero days  
				--  Also sets the v_charge_detail_id  
				BEGIN
					SELECT NVL(max(charge_detail_id),0)
					  INTO v_charge_detail_id 
					  FROM CHARGE_DETAIL
					 WHERE booking_id = records.booking_id;
			    EXCEPTION 
					when NO_DATA_FOUND then 
					    v_charge_detail_id := 0;
					when others then 
						v_charge_detail_id := 0;
			    END;
				--dbms_output.put_line('current charge detail ' ||v_charge_detail_id);
			if gv_debug = TRUE and gv_debug_inmate = records.offender_id THEN
				DBMS_OUTPUT.put_line(records.offender_id||' ' ||records.status_date||' ' ||records.status_end||' ' ||records.booking_id||' ' ||records.custody_status_id);
			end if ;
				MP_MJRS_Enddate_charge_detail(records.offender_id, records.BOOKING_ID, records.STATUS_DATE, v_charge_detail_id);  
				 
				v_status := 'TRUE';

			    -- start main processing of the record  (based on record types (status) in query above.
				IF (records.STATUS = 'NEW SENTENCE' or records.STATUS = 'NEW MISSING' or v_inmate_exists = 'NO') THEN 					    
					-- is the inmate new?  or needs an update?
					BEGIN
						SELECT 'YES' INTO v_inmate_exists FROM INMATES i WHERE i.offender_id = records.offender_id;  
					EXCEPTION WHEN no_data_found THEN
						-- Inmate not in system, insert please.
						v_inmate_exists := 'NO';
					END; 				 			
					IF v_inmate_exists = 'NO' THEN      
						MP_mjrs_inmate_insert(v_batch_id,records.offender_id,0,v_status);
					ELSE
						MP_mjrs_inmate_update(v_batch_id,records.offender_id,0,records.CUSTODY_STATUS,v_status);  
					END IF;   
					INC_inmates_Batch(v_batch_id);

					IF records.STATUS = 'NEW MISSING' THEN
						mjrs_charge_add(   v_batch_id,
					                          records.offender_id,
					                          records.booking_id,
					                          records.custody_status_id,
		   			                          records.CUSTODY_STATUS,
					                          records.STATUS_DATE, -- start
					                          records.STATUS_END, 
					                          v_charge_detail_id,  -- charge_detail_id max value set above
					                          v_status);					
					END IF;
			    ELSIF (records.STATUS = 'STATUS UPDATE') THEN
					/*	  Create charge_detail row
						  Set "Inactive" status
						If charges row for this booking does not exist then 
							Create charges row
						End if
					*/
					mjrs_charge_add(   v_batch_id,
				                       records.offender_id,
				                       records.booking_id,
				                       records.custody_status_id,
			                           records.CUSTODY_STATUS,
				                       records.STATUS_DATE, -- start
				                       records.STATUS_END,
				                       v_charge_detail_id,  -- charge_detail_id max value set above
				                       v_status);

	 		    ELSIF (records.STATUS = 'RELEASE INMATE') THEN
	 		    	/*	if not work release inmate
		 		    	    Update rent and closing dates
							All statuses are summed into one row in charges. 
							  Status is set to 'Active'
							Add transaction log entry
			    	*/  
					--dbms_output.put_line('main release inmate: '||records.offender_id);		
			    	
	  				MP_mjrs_release_inmate(	v_batch_id,
					                        records.offender_id,
					                        records.booking_id,
					                        records.custody_status_id, 
				                          	records.CUSTODY_STATUS,
					                        records.STATUS_DATE, -- start
					                        records.STATUS_END,
					                        v_charge_detail_id,
					                        v_status); 
	

			    ELSIF  (records.STATUS = 'WORK RELEASE') THEN
				    /*	Zero rent on previous
						Add status work release to charge_detail
						Add status to charges (1 reg row, 1 work release row, update charge_id to match)
						Add end date to charge_details
						  Inmate stays in "Inactive" status
						Set the work release flag
				    */
		  			MP_mjrs_work_release_inmate(	v_batch_id,									
							                        records.offender_id,
							                        v_charge_detail_id,
							                        records.booking_id,
							                        records.custody_status_id,
							                        records.CUSTODY_STATUS,
													records.STATUS_DATE, -- start
							                        records.STATUS_END,  
							                        v_status); 		    

			    ELSE
			        -- unknow status through error 
		 	        dbms_output.put_line('Un accounted for record.status type.');
	
			    END IF;
			END IF;		
 		END LOOP;
		update OFFTRK_IMPORT_BATCHES
		set trans_log_end = TRANSACTIONLOG_SEQ.CURRVAL
		where batch_id = v_batch_id;
		commit;
 	END;
 	
END MPK_mjrs_Batch_Processing;
/
