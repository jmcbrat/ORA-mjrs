delete from OFFTRK_IMPORT_BATCHES where batch_id>0;

	INSERT
	  INTO OFFTRK_IMPORT_BATCHES
           (batch_id, IMPORT_DATE, TRANSACTIONS, charges,inmate)
    VALUES
           (import_batches.nextval,
            to_date('12/09/2008 07:05:59'),
            0,
            0,
            0
           );


		SELECT *
		  FROM OFFTRK_IMPORT_BATCHES;

alter table OFFTRK_IMPORT_BATCHES
add (
trans_log_start number,
trans_log_end   number);
