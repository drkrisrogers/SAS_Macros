
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
Updates: 
;


%macro char_to_num(dsin=,dsout=,varc=,varn=,varcf=,varcn=);
%local dsin dsout varc varn varcf varcn dsid vid vlab;

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
%let vid=%sysfunc(&dsid,&varc);
%let vlab=%sysfunc(&dsid,&vid);
%let rc=%sysfunc(close(&dsid);

*Create the informat in a datastep, then read it with proc format;
data work.informat (keep=fmtname type start end label );
	retain fmtname 'Convifmt' type 'I';
	attrib start length=$32 end length=$32 label length=$32;
	set work.infvals;
	sequence+1;
 	start=fval;
	end=start;
	label=trim(left(put(sequence,best12.)));
 run;
proc format library=work cntlin=work.informat;
run;

*Create the final format in a datastep, then read it with proc format;
data work.format (keep=fmtname type start end label );
	retain fmtname "%qksubstr(&varcn,1,%eval(%length(&varcn)-1))" type 'N';
	attrib start length=$32 end length=$32 label length=$32;
	set work.infvals;
	sequence+1;
 	start=trim(left(put(sequence,best12.)));
	end=start;
	label=fval;
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
%mend char_to_num;
