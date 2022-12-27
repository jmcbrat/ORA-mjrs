
select * from OFFTRK_IMPORT_BATCHES;
/*
delete  OFFTRK_IMPORT_BATCHES where batch_id  >100;

delete OFFTRK_IMPORT_CHARGE_LOG where batch_id  >100;

delete OFFTRK_IMPORT_INMATE_LOG where batch_id  >100;

delete CHARGES where batch_id >100;

delete CHARGE_detail where batch_id >100;
--delete inmates where modified_by =0;

delete TRANSACTION_LOG where TRANSACTION_date > sysdate-1 ;to_Date('11/15/2008', 'mm/dd/yyyy'); -- between 848 and 894;

delete INMATES_ADDRESS_HISTORY where modified_by = 0;

commit;
-- initial load of the data
--execute MPK_mjrs_Batch_Processing.MP_mjrs_inital_load(sysdate-1);
*/
execute MPK_ppmjrs_Batch_Processing.MP_mjrs_Batch_Run(sysdate);

select * from pp_OFFTRK_IMPORT_BATCHES order by batch_id;
