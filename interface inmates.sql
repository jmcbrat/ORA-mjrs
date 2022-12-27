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
		MACOMB.mcmb_fnt_DOB(id.entity_id) as DOB,
		substr(pi.social_security_number,1,3)||'-'||substr(pi.social_security_number,4,2)||'-'||substr(pi.social_security_number,6,4) as SSN,
		'1' as modified_by,
		sysdate as modified_date,
		--(select account_status_id from ACCOUNT_STATUS_TYPES where account_status_desc = 'Active') as ACCOUNT_STATUS_ID,
		'yes' as IS_VALID_ADDRESS
		--'no' as IS_LEGAL_JUDGEMENT,
		--'no' as IS_COLLECTIONS,
		--'no' as IS_LEGACY_DATA,
		--'no' as IS_LEGACY_CORRECTED
from    epic.eh_active_booking ab,
        epic.eh_offender_ids id,
        epic.EH_PERSON_IDENTITY pi,
        EPIC.eh_operators_license ol,
        EPIC.eh_address ad--,
       -- EPIC.eh_telephone_records tr,
       -- EPIC.eh_telephone_records tr2
where   --epic.ef_is_active_booking(id.entity_id)='TRUE'
    id.entity_id = pi.entity_id
  and   macomb.mf_jil_master_alias(id.entity_id, pi.IDENTITY_ID) =1
  and   ol.identity_id = pi.IDENTITY_ID
  and   ol.primary_dl = 'Y'
  and   ad.entity_id = id.entity_id
  and   ad.primary_flag  = 'Y'
  and   mf_new_sentence(ab.entity_id) = 'Y';
