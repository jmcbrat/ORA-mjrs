CREATE OR REPLACE
PROCEDURE MP_mjrs_inmate_insert (
		p_batch_id          IN      NUMBER,
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
   
	--dbms_output.put_line('Insert inmate....');
    -- inmates
    begin 
    	insert into inmates (OFFENDER_ID, NAME_FIRST, NAME_FAMILY, NAME_OTHER, STREET, CITY_TOWN_LOCALE,
		STATE_PROVINCE_REGION, POSTAL_CODE, PHONE_NUMBER, ALTERNATIVE_PHONE_NUMBER,  
                SOCIAL_SECURITY_NUMBER, DRIVERS_LICENSE_NUMBER, MODIFIED_BY, MODIFIED_DATE, ACCOUNT_STATUS_ID, MAIL_STATUS_ID, 
                IS_LEGAL_JUDGMENT, IS_COLLECTIONS, IS_LEGACY_DATA, IS_LEGACY_CORRECTED, DATE_OF_BIRTH) 
		 select  id.offender_id as OFFENDER_ID,
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
				-- inactive (housed in jail
				-- active (released)
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
		
		--v_inc_trans := MF_INC_Batch(p_batch_id );
		  
		COMMIT;	
	END;
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
/
