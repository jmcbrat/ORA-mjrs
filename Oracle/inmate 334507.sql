			SELECT 	b.entity_id                AS entity_id,
			        id.OFFENDER_ID				AS offender_id,
					c.charge_id 				AS charge_id,
			        c.statute_id 				AS statute_id,
			        es.statute_number 			AS pacc,
			        es.statute_description 		AS charge_desc,
			    	EPIC.ef_lookup_text('STATUTE CLASS', es.code_statute_class, 'UC') AS charge_class,
			        s.sentence_id 				AS sentence_id,
			       	charge_id_number 			AS charge_id_number,
			       	--null /*ca.agency_id */				AS agency_id,
			       	mf_complaint_dept(c.charge_id ,'C')		AS complaint_dept,
			       	--cct.court_id 				AS court_id,
			       	cs.case_number 				AS case_no,
			       	EPIC.mcmb_fnt_courtname(c.charge_id) AS court_name,
			       	decode(macomb.mf_NextCourtDate_Charge(c.charge_id),'TBN','Call Court','01/01/2200','Call Court','12/25/2025','Call Court',macomb.mf_NextCourtDate_Charge(c.charge_id))  AS court_date,
			       	EPIC.ef_next_court_division(b.entity_id) AS court_division,
			       	EPIC.ef_lookup_text('JUDGE NAME',EPIC.ef_next_court_judge(b.entity_id),'UC') AS court_judge,
					--decode(mf_is_WRIT_booking(b.booking_id),'YES',0,       -- added WRIT logic 6/15/09
							nvl(decode(c.sentence_id,NULL,
										to_number(bc.cash_only_bail_amount,'99999999D99')/*+decode(bc.is_bailable||c.arrest_reason,'Y104',10.00,'YMW',10.00,'YFM',10.00,'YPV',10.00,0.00)*/,
										to_number(mf_FineAmount(c.sentence_id),'99999999D99')),0)  AS amount,
					decode(c.sentence_id,NULL, 'BAIL', 'FINE') AS amount_type,                                 -- added the above snippet to add missing fee
					decode(c.sentence_id,NULL, 'U', 'S') AS Trans_type,
					decode(c.sentence_id,NULL, 2, 1) AS sortorder,
					decode(EPIC.ef_get_attribute_value('10 PERCENT BOND',bc.BAIL_CONDITION_ID),'YES',
																		'Y',
																		'N') AS reduceamount,
					EPIC.ef_epic_date_to_date(so.paid_out_date) AS paidoutdate,
					EPIC.ef_epic_date_to_date(so.unpaid_out_date) AS unpaidoutdate,
					--decode(mf_is_WRIT_booking(b.booking_id),'YES',0,       -- added WRIT logic 6/15/09
						decode(bc.is_bailable||c.arrest_reason,'Y104',10.00,'YMW',10.00,'YFM',10.00,'YPV',10.00,0.00)  AS surcharge_amount,
					c.charge_state,
					sysdate,
					b.entity_id || c.charge_id,
					c.arrest_reason as CALLBEFOREBAIL,
					--ltrim(rtrim(--mf_GenAttribExists((select a.court_Appearance_id from  epic.eh_court_Appearance a where  a.owner_id  = cs.case_id), 'PER DISPO')||
					--            mf_GenAttribExists((select a.court_Appearance_id from  epic.eh_court_Appearance a where  a.owner_id  = bc.bail_condition_id), 'COURT DISPOSITION'))),
	                EPIC.ef_epic_date_to_date(s.sentence_end_date) as charge_released,
					--EPIC.ef_epic_date_to_date(EPIC.epp_booking_dates.start_date(b.booking_id)) as charge_booked
					epic.ef_epic_date_to_Date(c.offense_date)  as charge_booked
			FROM 	EPIC.eh_charge c,
					EPIC.eh_booking b,
					EPIC.eh_active_booking ab,
					--EPIC.eh_charge_agency ca ,
			     	EPIC.eh_case cs,
			     	EPIC.eh_case_charge cc,
			     	--EPIC.eh_case_court cct,
			     	--EPIC.eh_entity_organization eo,
			     	EPIC.eh_sentence s,
			     	EPIC.eh_sentence_out_dates so,
			     	EPIC.epic_statutes es,
			     	EPIC.eh_bail_condition bc,
			     	EPIC.eh_bail_condition_charge bcc,
					EPIC.eh_offender_ids id
			WHERE b.booking_id = c.booking_id
			  AND id.entity_id = b.entity_id
			  AND s.sentence_id (+) = c.sentence_id
			  AND cs.booking_id = b.booking_id
			  AND cc.charge_id = c.charge_id
			  AND cc.case_id = cs.case_id
			  AND es.STATUTE_ID = c.statute_id
			  AND so.sentence_id (+)  = c.sentence_id
			  AND bc.booking_id = b.booking_id
			  AND bcc.charge_id = c.charge_id
			  AND bc.bail_condition_id = bcc.bail_condition_id
			  AND b.booking_id = ab.booking_id
			  AND id.ENTITY_ID = ab.entity_id
			  and mf_is_HYTA_charge2(c.charge_id) = 'NO'
			  AND c.charge_state > 0 AND c.charge_state < 6
			  AND EPIC.ef_is_active_booking(b.entity_id)='TRUE'
			  and offender_id = '334507'
			  ORDER BY id.OFFENDER_ID, c.index_number;
