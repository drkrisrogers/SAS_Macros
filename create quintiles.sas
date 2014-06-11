proc summary data=work.seifa_lga;
	var SEIFA_Score;
	weight Usual_Resident_Population;
	output out=work.quintiles  p20(SEIFA_Score)=p_20 p40(SEIFA_Score)=p_40 p60(SEIFA_Score)=p_60 p80(SEIFA_Score)=p_80;
run;

proc transpose data=work.quintiles (drop=_type_ _freq_) out=work.quintiles;
run;

 
data quintiles (drop=_NAME_ COL1 lastval);
   	length label $ 11 Start $12 end $12;
   	set work.quintiles () end=last;
   	retain fmtname 'SeifaQ' type 'n' SEXCL 'N' EEXCL 'Y' lastval;
   	count+1;
   	label=put(cat(count,"Q"),$11.);
   	if _n_=1 then do; start='LOW'; HLO='L'; end;
   	else start=lastval;
	end=put(col1,11.);
	lastval=end;

	output;
	if last then do;
		hlo='H';
		start=lastval;
		end='HIGH';
		eexcl='N';
   		label=put(cat(count+1,"Q"),$11.);
	    output;
	end;
run;

proc format cntlin=work.quintiles;
run;
 
 
