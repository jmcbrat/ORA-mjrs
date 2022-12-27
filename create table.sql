describe  OFFTRK_IMPORT_BACTHES;
create table offtrk_import_batches (
BATCH_ID		NUMBER(38) not null,
IMPORT_DATE		DATE       not null,
TRANSACTIONS		NUMBER(28),
INMATE		NUMBER(28),
CHARGES		NUMBER(28));

drop table OFFTRK_IMPORT_BACTHES
