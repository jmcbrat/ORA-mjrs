CREATE OR REPLACE
PROCEDURE MP_mjrs_inmate_insert (
		p_offender_id       IN		VARCHAR2,
		p_user_id           IN      VARCHAR2,
		p_Status			   OUT	BOOLEAN
	 )
		
IS
/*	
	Purpose:		insert offendertrak inmate into mjrs
					
	Author:			Joseph McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
					----------	 -------------	------------------------------------------
					J. McBratnie 09/29/08		Created
*/  

begin
    -- inmates
    begin 
    	insert into mjrs.inmates
		select  id.offender_id,
				pi.NAME_FIRST  as firstname,
				pi.NAME_FAMILY as lastname,
				pi.NAME_OTHER  as othername,
				ad.street_number || ad.street_name || ad.flat_no_or_floor_level as street,
				ad.city_town_locale as city_town_local,
				ad.state_province_region as state_town_locale,
				ad.postal_code as postal_code,
				replace(replace(replace(replace(
				   replace(macomb.mcmb_fnt_phone_per_address(id.entity_id, ad.address_id),'-',''),' ',''),'.',''),'(',''),')','') as phone_number,
				replace(replace(
				   replace(macomb.MF_EC_Area(id.entity_id)||macomb.MF_EC_PhNumber(id.entity_id),'-',''),' ',''),'.','') as ALTERNATIVE_PHONE_NUMBER,
		        ol.drivers_license_number,
				MACOMB.mcmb_fnt_DOB_gvt_format(id.entity_id) as DOB,
				substr(pi.social_security_number,1,3)||'-'||substr(pi.social_security_number,4,2)||'-'||substr(pi.social_security_number,6,4) as SSN,
				-- user ID listed here
				  p_user_id as modified_by,
				--  
				sysdate as modified_date,
				(select account_status_id from ACCOUNT_STATUS_TYPES where account_status_desc = 'Active') as ACCOUNT_STATUS_ID,
				'yes' as IS_VALID_ADDRESS, 
				'no' as IS_LEGAL_JUDGEMENT, 
				'no' as IS_COLLECTIONS, 
				'no' as IS_LEGACY_DATA, 
				'no' as IS_LEGACY_CORRECTED
		from    epic.eh_offender_ids id,
		        epic.EH_PERSON_IDENTITY pi,
		        EPIC.eh_operators_license ol,
		        EPIC.eh_address ad--,
		       -- EPIC.eh_telephone_records tr,
		       -- EPIC.eh_telephone_records tr2
		where   epic.ef_is_active_booking(id.entity_id)='TRUE'
		  and   id.entity_id = pi.entity_id
		  and   macomb.mf_jil_master_alias(id.entity_id, pi.IDENTITY_ID) =1
		  and   ol.identity_id = pi.IDENTITY_ID
		  and   ol.primary_dl = 'Y'
		  and   ad.entity_id = id.entity_id
		  and   ad.primary_flag  = 'Y' 
		  and   ad.entity_id = id.entity_id
		  and   ad.primary_flag  = 'Y' 
		  and   id.offender_id = p_offender_id;
	EXCEPTION 
		WHEN DUP_VAL_ON_INDEX THEN
			p_Status := FALSE;
			
	end;
    
 	-- inmates_stmt_info table setup
	begin
		insert into INMATES_STMT_INFO
			(OFFENDER_ID, 
			 OVERRIDE_MONTHLY_AMT_DUE, 
			 OVERRIDE_CURRENT_AMT_DUE, 
			 LAST_PAYMENT_DATE, 
			 LAST_PAYMENT_AMT, 
			 LAST_STMT_AMT_DUE
			)
		values
			(p_offender_id,
			 0.00,
			 0.00,
			 null,
			 null,
			 null
			);  
	EXCEPTION 
		WHEN DUP_VAL_ON_INDEX THEN
			p_Status := FALSE;
	end;
			
		commit;
		p_Status := TRUE;
		
end;
/
