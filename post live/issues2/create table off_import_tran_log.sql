describe OFFTRK_IMPORT_CHARGE_LOG;

create table offtrk_import_tran_log
(
BATCH_ID	NUMBER(38) not null,
OFFENDER_ID	VARCHAR2(64) not null,
CHARGE_ID	NUMBER(38) not null,
TRANSACTION_SEQ	NUMBER(38) not null,
transaction_code  varchar2(4),
amount            number(11,2),
update_date  date
);
