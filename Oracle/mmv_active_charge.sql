create MATERIALIZED VIEW MMV_JIL_CHARGE
   PCTFREE 5 PCTUSED 60 
   TABLESPACE macomb 
   STORAGE (INITIAL 50K NEXT 50K) 
   USING INDEX STORAGE (INITIAL 25K NEXT 25K)
   REFRESH START WITH ROUND(SYSDATE + 1) + 4/24 
   NEXT  ROUND(SYSDATE + 1) + 4/24  
   WITH PRIMARY KEY
AS SELECT 	b.entity_id             AS entity_id,
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
		EPIC.ef_offender_id(b.entity_id)||' - '||c.charge_id  AS web_charge_pk,
		decode(EPIC.ef_get_attribute_value('10 PERCENT BOND',bc.BAIL_CONDITION_ID),'YES',
															'Y',
															'N') AS reduceamount,
		EPIC.ef_epic_date_to_date(so.paid_out_date) AS paidoutdate,
		EPIC.ef_epic_date_to_date(so.unpaid_out_date) AS unpaidoutdate
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
  AND s.sentence_id (+) = c.sentence_id
  AND cs.booking_id = b.booking_id
  AND cc.charge_id = c.charge_id
  AND cc.cASe_id = cs.cASe_id
  AND cct.cASe_id = cs.cASe_id
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
       EPIC.ef_lookup_text('STATUTE CLASS', code_charge_severity, 'UC') AS charge_clASs,
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
        EPIC.mcmb_fnt_offenderidfrombk(b.booking_id)||' - '||h.hold_id,
   	    decode(sign(instr(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id),'10%')+
  					instr(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id),'10 %')+
   					instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'10 PERCENT'))-
   					(instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'NO 10')*100)-
   					(instr(upper(EPIC.ef_get_attribute_value('HOLD INFO',h.hold_id)),'NO10')*100),
				  					1,'Y','N') AS reduceamount,
		NULL AS paidoutdate,
		NULL AS unpaidoutdate
FROM EPIC.eh_booking_holds h,
     EPIC.eh_active_booking b,
     EPIC.eh_entity_organization eo
WHERE b.booking_id = h.booking_id
  AND eo.entity_id = h.agency_id