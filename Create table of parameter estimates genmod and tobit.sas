%macro est(table=work.estimates,output=genmod,outdata=);
%local levels;
%if (&output=genmod) %then %do;
	data work.estimates (drop=estimate df StdErr LowerWaldCL UpperWaldCL ChiSq ProbChiSq or l95 u95 where=(parameter ne 'Scale'));
		set work.estimates;
		
			l95=exp(LowerWaldCL);
			u95=exp(UpperWaldCL);
			ci=cat(strip(put(round(exp(estimate),.01),6.2)),' (',strip(put(round(l95,0.01),6.2)),' - ',strip(put(round(u95,0.01),6.2)),')');
		
		format u95 4.2 l95 4.2;
	run;
	
	data work.estimates;
		set work.estimates;
		retain ccount lcount cname;
		if _n_ =1 then do;
			ccount=1;
			lcount=1;
		end;
		else if parameter ne cname then do;
			ccount+1;
			lcount=1;
		end;
		else lcount+1;
		cname=parameter;
	run;

	proc sql noprint;
		select name into :levels separated by ' '
		from dictionary.columns
		where libname="WORK" and memname="CLASS"  and name eqt "X";
	quit;

	data work.class (where=(ref=1) drop=control_var &levels i param);
		set work.class (rename=(class=parameter value=level1) );
		retain param;
		if _n_=1 then param=parameter;
		else if missing(parameter)=1 then parameter=param;
		param=parameter;

		array levels{*} &levels;
		ref=1;
		do i=1 to dim(levels);
			if levels{i}=1 then ref=0;
		end;
		if ref=1 then do; ci='Reference'; lcount=0; end;
	run;

	data work.estimates;
		set work.estimates
		    work.class (drop=ref);
	run;

	proc sort data=work.estimates;
		by parameter descending lcount ;
	run;

	data work.estimates;
		set work.estimates;
		retain ccount_1;
		if _n_=1 then ccount_1=ccount;
		else if ccount=. then ccount=ccount_1;
		ccount_1=ccount;
		if level1='.' then level1='Missing';
	run;

	proc sort data=work.estimates out=work.estimates (keep=parameter level1 ci);
		by ccount lcount;
		where parameter ne 'Intercept';
	run;
	proc sql noprint;
		drop table work.class;
	quit;
%end;
%else %if (&output=qlim) %then %do;
data work.estimates (keep=parameter level1 ci pcount lcount where=(parameter ne '_Sigma'));
	set work.estimates;
	*Remove extra characters from beginning of the label of each level;
	level1=scanq(level1,2,"_");
	*Calculate concatenated estimate and wald CI for each level;
	if estimate ne 0 and stderr ne . then do;
		l95=estimate-(1.96*stderr);
		u95=estimate+(1.96*stderr);	
		ci=cat(round(estimate,.1),' (',round(l95,0.1),' - ',round(u95,0.1),')');

	end;
	*Set CI column to value reference for reference levels;
	else ci='Reference';
	*Set up retained variable (lastparm) so that a comparison can be made between the current and previous row;
	attrib lastparm length=$17;
	retain lastparm;
	*For the first observation, set lasparm to missing to avoid error messages, and start the counting process;
	if _n_=1 then do;
		lastparm=' ';
		pcount=1;
		lcount=1;
	end;
	*pcount increases for each new variable in the table, and lcount is set to 1;
	else if parameter ne lastparm then do;
		pcount+1;
		lcount=1;
	end;
	*Within a paramater, leave pcount and increase lcount;
	else lcount+1 ;
	*Move the current paramater value to lastparm for comparison in the next row;
	lastparm=parameter;

run;
*Sort using pcount and lcount to keep the dataset in order, and to facilitate by processing;
proc sort data=work.estimates;
	by pcount lcount;
run;
*Replace the pcount variable value for the last observation (reference value) to 0 for the next sort procedure;
data work.estimates;
	set work.estimates;
	by pcount;
	if last.pcount then lcount=0;
	*Replace the parameter label for subsequent levels other than first with a blank;
	else Parameter=' ';
run;
*Final sort to produce dataset;
proc sort data=work.estimates out=work.estimates ;
	by pcount lcount;
run;
*Insert blank rows under each paramater;
data work.estimates (drop=pcount lcount);
	set work.estimates;
	by pcount;
	if first.pcount and last.pcount and ci='Reference' then delete;

	output;

	if last.pcount then do;
		parameter=' ';
		level1=' ';
		ci=' ';
		output;
	end;
run;
%end;
%else %if (&output=ph) %then %do;
	data work.estimates (keep=parameter ClassVal0 ci );
		set work.estimates;
		
			l95=exp(Estimate-(1.96*StdErr));
			u95=exp(Estimate+(1.96*StdErr));
			ci=cat(round(exp(estimate),.01),' (',round(l95,0.01),' - ',round(u95,0.01),')');
		
 	run;
	
	data work.estimates;
		set work.estimates;
		retain ccount lcount cname;
		if _n_ =1 then do;
			ccount=1;
			lcount=1;
		end;
		else if parameter ne cname then do;
			ccount+1;
			lcount=1;
		end;
		else lcount+1;
		cname=parameter;
	run;

	proc sql noprint;
		select name into :levels separated by ' '
		from dictionary.columns
		where libname="WORK" and memname="CLASS"  and name eqt "X";
	quit;

	data work.class (where=(ref=1) drop=control_var &levels i param);
		set work.class (rename=(class=parameter value=level1) );
		retain param;
		if _n_=1 then param=parameter;
		else if missing(parameter)=1 then parameter=param;
		param=parameter;

		array levels{*} &levels;
		ref=1;
		do i=1 to dim(levels);
			if levels{i}=1 then ref=0;
		end;
		if ref=1 then do; ci='Reference'; lcount=0; end;
	run;

	data work.estimates;
		set work.estimates (rename=(classval0=level1))
		    work.class (drop=ref );
	run;

	proc sort data=work.estimates;
		by parameter descending lcount ;
	run;

	data work.estimates;
		set work.estimates;
		retain ccount_1;
		if _n_=1 then ccount_1=ccount;
		else if ccount=. then ccount=ccount_1;
		ccount_1=ccount;
		if level1='.' then level1='Missing';
	run;

	proc sort data=work.estimates out=work.estimates (keep=parameter level1 ci);
		by ccount lcount;
	run;
	proc sql noprint;
		drop table work.class;
	quit;
%end;
	data &outdata;
		set work.estimates;
	run;

	proc sql noprint;
		drop table work.estimates;
	quit;

%mend est;
