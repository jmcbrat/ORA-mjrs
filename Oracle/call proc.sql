VARIABLE VCUR REFCURSOR;

--execute macomb.mp_matching_offenders('-5','123','123','370801234','LITTLE','DOUG', :VCUR);
execute MACOMB.mpk_avgdailypop_jdm.Calculate('2007020618:43:18-300','2007020818:43:18-300', :VCUR);

print VCUR
