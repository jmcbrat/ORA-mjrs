select  PROCESS_ID as pid, STARTED, ENDED, CURRENTLY, CLEAR_DB as CLR, CHARGE as chrg, BOOKING as b, HOLD as h, ALIAS as a,
        GRAMMAR as g, INMATE as i, MUG as m, PROD as prod, EXPORT as exp from MT_JIL_LOG  jl
where process_id = (select max(process_id) from mt_jil_log)  order by jl.process_id desc
