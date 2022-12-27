select substr(volumepath,instr(volumepath,'/')+1,length(volumepath)-instr(volumepath,'/')+1),volumepath   from epic.EPICVOLUME where substr(volumepath,1,instr(volumepath,'/')-1)<>'TRAINING' ; order by 3 ;
update epic.EPICVOLUME
set volumepath = concat('TRAINING',substr(volumepath,instr(volumepath,'/')+1,length(volumepath)-instr(volumepath,'/')+1))
where substr(volumepath,1,instr(volumepath,'/')-1)<>'TRAINING'
