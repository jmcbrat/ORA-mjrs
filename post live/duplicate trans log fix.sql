select * from TRANSACTION_LOG
where offender_id = '146491';

delete from transaction_log where transaction_seq = '26357';

select offender_id, charge_id, count(*) from TRANSACTION_LOG
group by offender_id, charge_id
having count(*)>1
order by 3 desc;

select * from TRANSACTION_LOG
where offender_id = '306275'
and charge_id = 1;

delete from TRANSACTION_LOG t where t.TRANSACTION_SEQ <> (select max(tl.TRANSACTION_SEQ) from TRANSACTION_LOG tl where tl.offender_id = t.offender_id and  tl.charge_id = t.charge_id) and t.offender_id =

  '311410' and t.charge_id = 1 ;

delete from TRANSACTION_LOG t where t.TRANSACTION_SEQ <> (select max(tl.TRANSACTION_SEQ) from TRANSACTION_LOG tl where tl.offender_id = t.offender_id and  tl.charge_id = t.charge_id) and t.offender_id = '42617' and t.charge_id = 2;

