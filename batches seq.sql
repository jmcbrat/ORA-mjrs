--select IMPORT_DATE from OFFTRK_IMPORT_BACTHES

insert into OFFTRK_IMPORT_BATCHES
(batch_id, IMPORT_DATE, TRANSACTIONS)
values
 (import_batches.nextval,
 sysdate,
 0 )
 ;

 update OFFTRK_IMPORT_BATCHES
 set  batch_id = 1;


 select * from OFFTRK_IMPORT_BAtCHES  ;


select max(import_date) from OFFTRK_IMPORT_BACTHES;

delete from offtrk_import_batches where batch_id = 2;
