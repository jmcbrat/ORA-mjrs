CREATE OR REPLACE
PROCEDURE MP_pp_MJRS_POST_TRAN
( OffenderId IN STRING
, ChargeId IN NUMBER
, TranCode IN STRING
, TranAmt IN NUMBER
, RunDate IN DATE
, RunBy IN NUMBER
, PymtTypeId IN NUMBER
, RefNum IN STRING
)
IS
/*
	Purpose:		Post a transaction in MJRS 
					
	Author:			Sue Dunn

	Change Log:		Changed By	 Date Modified	Change Made
                                ----------	 -------------	------------------------------------------
                                S. Dunn           09/29/08        Created 
					                  
*/  
  action STRING(10);
  fromBal STRING(10);
  applyTranCode STRING(4);
  resetCnt STRING(10); 
  curBal NUMBER;
  legBal NUMBER;
  collBal NUMBER;
  amount NUMBER;
  nextSeq NUMBER;
  chargeBal NUMBER;
  val NUMBER;
BEGIN 
  BEGIN 
     SELECT lower(ACTION), nvl(APPLY_TRAN_CODE,'00'), lower(RESETS_STMT_COUNT)
     INTO action, applyTranCode, resetCnt FROM TRANSACTION_CODES WHERE TRANSACTION_CODE = TranCode;
      
     amount := TranAmt;
     if (action = 'credit') then
        amount := 0 - TranAmt;
     end if;
  
     select pp_TRANSACTIONLOG_SEQ.NEXTVAL INTO nextSeq FROM dual;
     
     INSERT INTO TRANSACTION_LOG (OFFENDER_ID, CHARGE_ID, TRANSACTION_SEQ, TRANSACTION_DATE, TRANSACTION_CODE, TRANSACTION_AMT, CURRENT_BALANCE, PAYMENT_TYPE_ID, REFERENCE_NUMBER, POSTED_BY, IS_DELETED, STATEMENT_ID, POSTED_DATE)
     VALUES (OffenderId, ChargeId, nextSeq, RunDate, TranCode, amount,  null,
             PymtTypeId, RefNum, RunBy, 'no', NULL, SYSDATE);
  END;
  commit;

  BEGIN
     val := to_number(TranCode);
     if (val > 6999 and val < 8000) then  UPDATE INMATES_STMT_INFO 
          SET LAST_PAYMENT_DATE = RunDate,
              LAST_PAYMENT_AMT = TranAmt
          WHERE OFFENDER_ID = OffenderId;
     end if;    
       
     chargeBal := MF_pp_GET_CURRENT_BAL_ID (OffenderId, ChargeId);
          
     if (lower(resetCnt) = 'yes' OR chargeBal <= 0) then
        UPDATE pp_CHARGES 
        SET AGING = 0
        WHERE OFFENDER_ID = OffenderId and CHARGE_ID = ChargeId;
     end if;
  END;
  commit;
 
  collBal := mf_pp_get_collection_balance (OffenderId);
  legBal := mf_pp_get_legal_balance (OffenderId);
  curBal := mf_pp_get_current_balance (OffenderId);     

  if (collBal > 0) then
    UPDATE INMATES SET IS_COLLECTIONS = 'yes' WHERE OFFENDER_ID = OffenderId;
  else 
    UPDATE INMATES SET IS_COLLECTIONS = 'no' WHERE OFFENDER_ID = OffenderId;
  end if; 
  commit;

  if (legBal <= 0 and curBal <= 0) then
   UPDATE INMATES SET account_status_id = (select account_status_id from account_status_types 
                                           where account_status_desc = 'Inactive')
   where offender_id = OffenderId;    
  end if; 
  commit;

END MP_pp_MJRS_POST_TRAN;
/
