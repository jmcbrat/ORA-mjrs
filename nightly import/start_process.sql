select * from OFFTRK_IMPORT_BATCHES;

delete  OFFTRK_IMPORT_BATCHES where batch_id =69;

delete OFFTRK_IMPORT_CHARGE_LOG where batch_id =69;

delete OFFTRK_IMPORT_INMATE_LOG where batch_id =69;

delete CHARGES where batch_id =69;

--delete inmates where modified_by =0;

delete TRANSACTION_LOG where TRANSACTION_SEQ between 848 and 894;

----update OFFTRK_IMPORT_BATCHES
--set transactions = 1,
--    import_date = sysdate-1;

--commit;

execute MPK_mjrs_Batch_Processing.MP_mjrs_Batch_Run(sysdate);

select * from OFFTRK_IMPORT_BATCHES order by batch_id;
