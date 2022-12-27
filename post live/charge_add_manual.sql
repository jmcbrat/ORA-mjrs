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
				  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN MF_GET_LAST_RUN()
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
				  AND  id.offender_id = '327260'
				  --AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN MF_GET_LAST_RUN()
				  --                                                    AND sysdate
                                                ;

--declare p_status varchar2;
VARIABLE p_status varchar2;

execute MPK_mjrs_Batch_Processing.mjrs_charge_add(   -1,                 --v_batch_id,
				                       '327260',           --records.offender_id,
				                       '0KAWHHN000USJ2WS', --records.booking_id,
				                       '0KAWHHVER0USJZ10', --records.custody_status_id,
			                           1,                  --records.CUSTODY_STATUS,
				                       to_Date('11/25/2008 00:00:00'), --records.STATUS_DATE, -- start
				                       null,                           --records.STATUS_END,
				                       0, --zero is no rows v_charge_detail_id,  -- charge_detail_id max value set above
				                       :p_status);
