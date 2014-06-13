ods output CrossTabFreqs=work.ct;
proc freq data=acsum;
	table (ydx morph_short)*sexn /norow nopercent;
run;


*Ok, let's try my idea of converting existing character variables to numeric ones;
*In the first instance this will involve doing this manually so we have a set of output for comparison;

data work.acsum;
	set work.ac_ccr;

	if sex_ccr='M' then sexn=1;
	else if sex_ccr='F' then sexn=2;

	seifaq=input(seifa,1.);

	morphn=input(put(morph_short,morph.),morphcon.);

	format sexn sexn. seifaq seifaq. morphn morphn.;
	label seifaq='SEIFA';
	keep age_dx ydx aria seifaq topo_short morphn stage_dx censor censor_5 _apdcpostdx ;
run;



%local varc varn varcf varcn;

proc sql noprint;
	

sexn

agedx ydx aria seifaq topo_short morphn stage_dx censor_5 _apdcpostdx

*Step 1. read in the variable and dataset to 
