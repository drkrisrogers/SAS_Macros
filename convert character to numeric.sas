
*Title: Convert character to numeric;
*Author: Kris Rogers;
*Date: 16/6/2014;
*Purpose: Converts a single variable from character to numeric, with respect to the formatted value
		  of the original character variable. This is mostly to be used with the summary data macro
		  which will only work with numeric variables. This saves manual ifthenelse recoding (prone to error).
		  Currently does not label the new variable - this could be added later.
		  Minimal error checking - this macro assumes you have put in the right kind of variable, already
		  formatted etc.
		  Problems - could pull the wrong format if fmtsearch picks up another catalogue. Not sure what to do with this.
Updates: 18/07/2014 KR - Changed the way this deals with missing values: no longer used as a valid level
						instead they are kept as a missing value with the format label "MISSING". Could 
						add option to turn this on/off later - no need to right now.

						Added some quick checks to see if the input table exists, and all the keywords
						have been specified. Later should check if the formats exists and columns exist
						in the input dataset.;
 
%macro char_to_num(dsin=,dsout=,varc=,varn=,varcf=,varcn=,missing=no);
%local dsin dsout varc varn varcf varcn dsid vid vlab i macrovars scanvar;

%let macrovars=dsin dsout varc varn varcf varcn;
 %do i=1 %to (%sysfunc(countw(&macrovars));
	%let scanvar=%scan(&macrovars,&i);
 	%if %length(&&&scanvar)=0 %then %do;
		%put ERROR: THE INPUT KEYWORD (%upcase(&scanvar)) HAS NOT BEEN SPECIFIED. MACRO WILL END;
		%put ERROR: YOUR CODE IS BAD AND YOU SHOULD FEEL BAD;
		%goto exit;
	%end;
%end;

%if (%sysfunc(exist(&dsin)) ne 1) %then %do;
	%put ERROR: THE INPUT TABLE (%upcase(&dsin)) DOES NOT EXIST. MACRO WILL END;
	%put YOUR CODE IS BAD AND YOU SHOULD FEEL BAD.;
	%goto exit;
%end;



data work.infvals;
	set &dsin (keep=&varc);
	attrib fval length=$32.;
	fval=put(&varc,&varcf);
	drop &varc;
run;
 
proc sort data=work.infvals nodupkey;
	by fval;
run;

%let dsid=%sysfunc(open(&dsin));
%let vid=%sysfunc(varnum(&dsid,&varc));
%let vlab=%sysfunc(varlabel(&dsid,&vid));
%let rc=%sysfunc(close(&dsid));

*Create the informat in a datastep, then read it with proc format;
data work.informat (keep=fmtname type start end label );
	retain fmtname 'Convifmt' type 'I';
	attrib start length=$32 end length=$32 label length=$32;
	set work.infvals;
	sequence+1;
 	start=fval;
	end=start;
	label=trim(left(put(sequence,best12.)));
	if missing(start) then do;
		sequence=sequence-1;
		label='.';
	end;
run;
proc format library=work cntlin=work.informat;
run;

*Create the final format in a datastep, then read it with proc format;
data work.format (keep=fmtname type start end label );
	retain fmtname "%qksubstr(&varcn,1,%eval(%length(&varcn)-1))" type 'N';
	attrib start length=$32 end length=$32 label length=$32;
	set work.infvals;
if missing(fval) ne 1 then do;
	sequence+1;
	start=trim(left(put(sequence,best12.)));
	end=start;
	label=fval;
end;
else do;
	start='.';
	end='.';
	label='Missing';
end;
 run;
proc format library=work cntlin=work.format;
run;

data &dsout;
	set &dsin;
	&varn=input(trim(left(put(&varc,&varcf))),Convifmt.);
	format &varn &varcn;
	label &varn="%sysfunc(trim(%sysfunc(left(&vlab))))";
run;

 proc catalog catalog=work.formats;
	delete Convifmt.infmt;
quit;

proc sql noprint;
	drop table work.informat, work.format, work.infvals;
quit;

%exit: ; 
%mend char_to_num;
