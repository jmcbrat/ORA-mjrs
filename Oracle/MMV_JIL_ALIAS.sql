/*create MATERIALIZED VIEW MMV_JIL_ALIAS
   PCTFREE 5 PCTUSED 60
   TABLESPACE macomb
   STORAGE (INITIAL 50K NEXT 50K)
   USING INDEX STORAGE (INITIAL 25K NEXT 25K)
   REFRESH START WITH ROUND(SYSDATE) + 2/24
   NEXT  ROUND(SYSDATE) + 2/24
   WITH PRIMARY KEY
AS
  */
select 	id.entity_id AS entity_id,
        id.OFFENDER_ID AS offender_id,
		pi.identity_id AS alias_id,
		pi.name_family AS lastname,
		pi.name_first  AS firstname,
		pi.name_other  AS middlename,
		pi.name_suffix AS suffixname,
 	    NVL(NVL(to_char(EPIC.ef_epic_date_to_date(pi.DATE_OF_BIRTH),'MM/DD/YYYY'),
 	    		to_char(EPIC.ef_epic_date_to_date(pi.BIRTH_DATE_APPROX),'MM/DD/YYYY')),
 	                   'UNKNOWN') AS DOB,
 	    pi.CODE_NAME_TYPE AS CODE_NAME_TYPE,
 	    decode(pi.CODE_NAME_TYPE, 'MAS',id.entity_id, 'ALIAS') AS LINK_PK,
        sysdate as SNAPSHOT
FROM    EPIC.eh_person_identity pi,
		EPIC.eh_offender_ids id
WHERE	id.ENTITY_ID = pi.entity_id (+)
  AND	pi.CODE_NAME_TYPE in ('MAS','ALI')
  --AND EXISTS (select 1 from EPIC.eh_active_booking ab where id.entity_id = ab.entity_id)
  order by entity_id
