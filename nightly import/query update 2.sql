		SELECT distinct id.offender_id AS OFFENDER_ID,
		                b.booking_id   AS BOOKING_ID,
		                'NEW SENTENCE' AS STATUS,
		                1              AS ORDER_BY,
		                ''             AS CUSTODY_STATUS,
		                epic.ef_epic_date_to_date(bcs.date_start) AS status_start_date,
		                null as release_date
		FROM   epic.eh_sentence s,
		       epic.eh_charge c,
		       epic.eh_active_booking b,
		       epic.eh_booking_custody_status bcs,
		       epic.eh_offender_ids id
		WHERE  b.booking_id = c.booking_id
		  AND  c.sentence_id = s.sentence_id
		  AND  b.booking_id = bcs.booking_id
		  AND  b.entity_id = id.entity_id
		  AND  epic.ef_epic_date_to_date(date_entered) BETWEEN to_date('04/01/2007 10:05:51') --v_last_run_date
		  											       AND sysdate
	UNION  -- newly release inmates
		SELECT distinct id.offender_id,
		                b.booking_id ,
		                'RELEASE INMATE',
		                3,
		                '', -- code_custody_status
		                epic.ef_epic_date_to_date(bcs.date_start) AS status_start_date,
		                epic.ef_epic_date_to_date(r.actual_release) AS release_Date
		FROM   epic.eh_release r,
		       epic.eh_booking b,
		       epic.eh_booking_custody_status bcs,
		       epic.eh_offender_ids id,
		       epic.eh_charge c
		WHERE  b.booking_id = r.booking_id
		  AND  b.entity_id = id.entity_id
		  AND  b.booking_id = bcs.booking_id
		  AND  b.booking_id = c.booking_id
		  AND  c.sentence_id is not null
		  AND  epic.ef_epic_date_to_date(r.actual_release) BETWEEN to_date('04/01/2007 10:05:51') --v_last_run_date
		                                                       AND sysdate
	UNION  -- newly status changes
		SELECT distinct id.offender_id,
		                bcs.booking_id ,
		                'STATUS UPDATE',
		                2 ,
		                code_custody_status,
		                epic.ef_epic_date_to_date(bcs.date_start) AS status_start_date,
		                NULL AS release_Date
		FROM   epic.eh_booking_custody_status bcs,
		       epic.eh_active_booking b,
			   epic.eh_offender_ids id,
		       epic.eh_charge c
		WHERE  b.entity_id = id.entity_id
		  AND  b.booking_id = bcs.booking_id
		  AND  b.booking_id = c.booking_id
		  AND  c.sentence_id is not null        -- at least one charge sentenced
		  --AND  bcs.code_custody_status <>'3'    -- PAROLEE  4208
		  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN to_date('04/01/2007 10:05:51') --v_last_run_date
		                                                      AND sysdate
	ORDER BY 1,4 ;
