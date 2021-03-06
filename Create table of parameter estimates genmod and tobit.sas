**********
Author: Kris Rogers 
Title: Create table of transformed parameter estimates from proc genmod, tobit, and phreg
Date: One form or another of the macro has been kicking around for years
Purpose: Output from the above mentioned procedures is a bit rough. It is untransformed and needs work to 
  		 put it into a form that would be suitable for publication (e.g. reference levels). Run this macro
		after creating appropriate ods datasts and it will do it for you
Dependecies: No other macros, but you need these lines to work:
				proc genmod - "ods output ClassLevels=work.class ParameterEstimates=work.estimates"
				proc qlim - variables must be renamed with numeric order, because it is a crappy outdated procedure
Updates: 09/07/2014 KR - update to allow control over the number of decimal places (e.g. 1 for 0.1, 2 for 0.01) 
		 in the resulting dataset
		 15/07/2015 KR  - update to check for existence of the two essential datasets. I feel so grownup.
*************;
 

%macro est(table=work.estimates,output=genmod,outdata=,byvar=,estplaces=1,ciplaces=2);
%local levels estplaces ciplaces;

%if (&output=genmod or &output=ph) and (%sysfunc(exist(&table)) ne 1) %then %do;
	%put ERROR: THE TABLE OF ESTIMATES (%upcase(&table)) DOES NOT EXIST. MACRO WILL END.;
	%put YOUR CODE IS BAD AND YOU SHOULD FEEL BAD.;
	%goto exit;
%end;
%else %if (&output=genmod or &output=ph) and (%sysfunc(exist(work.class)) ne 1) %then %do;
	%put ERROR: THE TABLE OF VARIABLE LEVELS (WORK.CLASS) DOES NOT EXIST. MACRO WILL END.;
	%put YOUR CODE IS BAD AND YOU SHOULD FEEL BAD.;
	%goto exit;
%end;

%if (&output=genmod) %then %do;
	data work.estimates (drop=estimate df StdErr LowerWaldCL UpperWaldCL ChiSq ProbChiSq l95 u95 where=(parameter ne 'Scale'));
		set work.estimates;
		
			l95=exp(LowerWaldCL);
			u95=exp(UpperWaldCL);
			ci=cat(strip(put(round(exp(estimate),%sysevalf(10**(-1*&estplaces))),6.&estplaces)),' (',strip(put(round(l95,%sysevalf(10**(-1*&ciplaces))),6.&ciplaces)),' - ',strip(put(round(u95,%sysevalf(10**(-1*&ciplaces))),6.&ciplaces)),')');
		
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
		where parameter ne 'Intercept' and level1 ne 'Missing' ;
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
		ci=cat(strip(put(round(exp(estimate),%sysevalf(10**(-1*&estplaces))),6.&estplaces)),' (',strip(put(round(l95,%sysevalf(10**(-1*&ciplaces))),6.&ciplaces)),' - ',strip(put(round(u95,%sysevalf(10**(-1*&ciplaces))),6.&ciplaces)),')');

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
		ci=cat(strip(put(round(exp(estimate),%sysevalf(10**(-1*&estplaces))),6.&estplaces)),' (',strip(put(round(l95,%sysevalf(10**(-1*&ciplaces))),6.&ciplaces)),' - ',strip(put(round(u95,%sysevalf(10**(-1*&ciplaces))),6.&ciplaces)),')');
		
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
		if level1='Missing' then delete;
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

%exit: ;
%mend est;
