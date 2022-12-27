CREATE OR REPLACE
procedure mcmb_ep_set_booking_fee (
	-- jmcbratnie 12/06/2005
	-- Testing of booking fees
	--     
	sentity_ID		 in 	 eh_offender_ids.entity_id%type          DEFAULT 'UNKNOWN',
	ssucess             out  eh_offender_ids.offender_id%type             
)
As
	------ V A R I A B L E S ---------------------------
	c_debug		constant boolean := false;

    v_server_action_time       varchar2(20);
    v_trust_account_id         eh_trust_account.trust_account_id%type;
    v_trust_account_trans_id   eh_trust_account_trans.trust_account_trans_id%type;
	p_check_amount			   eh_trust_account_trans.amount%type;
	p_result                   epic_col_types.number_9%type;
	p_result_msg               epic_col_types.varchar_255%type;
	
    
	----------------------------------------------------

begin
	v_server_action_time        := epicdatenow;
	v_trust_account_id          := MCMB_FNT_get_trust_account_id(sentity_ID);

    p_check_amount := 0.00;
    p_result	   := 123;
    p_result_msg   := 'Booking Fee';
    
	begin --county fee
		v_trust_account_trans_id    := EPIC_IDS.new_epic_id();
		-- note ep_trust_account_trans resets the p_result_msg.  

		ep_trust_account_trans (v_trust_account_trans_id,	v_trust_account_id,	'CREDIT', v_server_action_time,
			null, p_result_msg, -10.00, null, null, 'CASH', null, null, 202,
			'Auto-generated', null, null, null, null, null, 
			ef_generate_autoid('TRUST ACCOUNTING TRANSACTION NUMBER',v_trust_account_id,'TRUST TRANSACTION'), 
			502, 10.00, 202, -10.00, 'N', -25, 	p_check_amount, 	p_result, p_result_msg );
			
		-- Insert into the audit table.  This was noted in the ep_trust_account_trans function
		insert into epicaudit.eh_trust_account_trans
			select *
			From eh_trust_account_trans
			Where
				trust_account_trans_id = v_trust_account_trans_id;

    exception
		when others then
	   		ssucess :='NO';
	End;
	begin --state fee
		v_trust_account_trans_id    := EPIC_IDS.new_epic_id();
	    p_result_msg   := 'Booking Fee';  		-- note ep_trust_account_trans resets the p_result_msg.  
	    
		ep_trust_account_trans (v_trust_account_trans_id,	v_trust_account_id,	'CREDIT', v_server_action_time,
			null, p_result_msg, -2.00, null, null, 'CASH', null, null, 203,
			'Auto-generated', null, null, null, null, null, 
			ef_generate_autoid('TRUST ACCOUNTING TRANSACTION NUMBER',v_trust_account_id,'TRUST TRANSACTION'), 
			503, 2.00, 203, -2.00, 'N', -25, 	p_check_amount, 	p_result, p_result_msg );

		-- Insert into the audit table.  This was noted in the ep_trust_account_trans function
		insert into epicaudit.eh_trust_account_trans
			select *
			From eh_trust_account_trans
			Where
				trust_account_trans_id = v_trust_account_trans_id;

    exception
		when others then
	   		ssucess :='NO';
	End;

End mcmb_ep_set_booking_fee;
/
