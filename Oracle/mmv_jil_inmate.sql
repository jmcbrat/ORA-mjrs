/*create MATERIALIZED VIEW MMV_JIL_INMATE
   PCTFREE 5 PCTUSED 60
   TABLESPACE macomb
   STORAGE (INITIAL 50K NEXT 50K)
   USING INDEX STORAGE (INITIAL 25K NEXT 25K)
   REFRESH START WITH ROUND(SYSDATE) + 2/24
   NEXT  ROUND(SYSDATE) + 2/24
   WITH PRIMARY KEY
AS*/

select      id.entity_id AS entity_id,
            id.OFFENDER_ID AS offender_id,
				pi.NAME_FAMILY as lastname,
			    pi.NAME_FIRST  as firstname,
				pi.NAME_OTHER  as othername,
   				decode(ep.CODE_GENDER,'_NOSP','U',ep.CODE_GENDER) as gender,
				NVL(NVL(to_char(epic.ef_epic_date_to_date(pi.DATE_OF_BIRTH),'MM/DD/YYYY'),
						to_char(epic.ef_epic_date_to_date(pi.BIRTH_DATE_APPROX),'MM/DD/YYYY')),
					'UNKNOWN_DOB') as DOB,
				decode(ep.JUVENILE_FLAG,'Y','Y','N') as juvenile_flag,
				epic.ef_epic_date_to_date(epic.epp_booking_dates.earliest_release_date(ab2.booking_id)) as paid_release,
    	   		epic.ef_epic_date_to_date(epic.epp_booking_dates.final_release_date(ab2.booking_id))    as Projected_release,--,
    	   		EPIC.mcmb_fnt_sent_Total_Amount(ab2.booking_id) as sent_total,
    	   		EPIC.mcmb_fnt_hold_Total_Amount(ab2.booking_id) as hold_total,
    	   		EPIC.mcmb_fnt_Bail_Total_Amount(ab2.booking_id) as bail_total,
				decode(ei.imageref, null,null,
					'\\' || ev.volumeserver || '\F$\FTP\' || ev.volumepath || '\' || ei.imageref) as mugpath,
   				vehicle_id as vehicle_id,
				eo.ORGANIZATION_NAME as tow_company,
	   		 decode(epic.ef_offender_CustStat(ab2.entity_id),
                  	'REGULAR INMATE','R',
					'WORK RELEASE','W',
                  	'KITCHEN TRUSTEE (White)','K',
                  	'GARAGE TRUSTEE (Orange)','O',
                  	'SPECIAL TRUSTEE (Green)','G',
                  	'R') as inmateclass,
    	   		epic.ef_epic_date_to_date(r.end_date) as restrictionuntil,
    	   		epic.ef_is_active_booking(ab2.entity_id) as active


--		   		 substr(epic.ef_location_name(ha.location_id ,'uc'),1,10) as cell,
--	   		 substr(epic.ef_location_path_name(ha.location_id ,'uc',4),1,instr(epic.ef_location_path_name(ha.location_id ,'uc',4),',')-1) as Level4,
--	   		 substr(epic.ef_location_path_name(ha.location_id ,'uc',5),1,instr(epic.ef_location_path_name(ha.location_id ,'uc',5),',')-1) as Level5,
--	  		 substr(epic.ef_location_path_name(ha.location_id ,'uc',6),1,instr(epic.ef_location_path_name(ha.location_id ,'uc',6),',')-1) as Level6,
--       		 substr(epic.ef_location_path_name(ha.location_id ,'uc',7),1,instr(epic.ef_location_path_name(ha.location_id ,'uc',7),',')-1) as level7,
--       		 substr(epic.ef_location_path_name(ha.location_id ,'uc',8),
--              instr(epic.ef_location_path_name(ha.location_id ,'uc',8),
--        		/*level7 */ substr(epic.ef_location_path_name(ha.location_id ,'uc',7),1,instr(epic.ef_location_path_name(ha.location_id ,'uc',7),',')-1)
--                    ,2)+1) as level8,
			 from   epic.EH_OFFENDER_IDS id,
			 		epic.EH_PERSON_IDENTITY pi,
			 		epic.eh_entity_person ep,
			 		epic.EH_VEHICLE v,
					epic.EH_ENTITY_ORGANIZATION  eo,
					epic.Epicvolume ev,
					epic.Epicimage ei,
					epic.Eh_entity_default_photo ph,
					epic.eh_active_booking ab2,
--					epic.eh_housing_assignments ha,
					epic.EH_ENTITY_RESTRICTION r
			 where  --id.entity_id = ab2.entity_id
  --			   and  epic.ef_is_active_booking(ab2.entity_id)='TRUE'
  			    id.entity_id = pi.entity_id
  			   and  id.entity_id = ep.entity_id
--  			   and  ab2.entity_id = ha.entity_id (+)
			   and  v.entity_id(+) = pi.entity_id
			   and  v.tow_company_id = eo.entity_id(+)
			   and  ei.imageref(+) = ph.photo_id
			   and  ev.volumeid(+) = ei.volumeid
			   and  ph.entity_id(+) = id.entity_id
  			   and  pi.code_name_type = 'MAS'
  			   and  ab2.entity_id (+)= id.entity_id
  			   and  ab2.entity_id = r.entity_id(+)
;
