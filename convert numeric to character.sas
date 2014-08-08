*Title: Convert numeric to character;
*Author: Kris Rogers;
*Date: 16/6/2014;
*Purpose: Converts a single variable from a numeric (with an associated numeric format) to a simple 
		  character variable with the same label;

%macro num_to_char(dsin=,dsout=,varn=,varnf=,varc=,vlength=12);
%local dsin dsout varc varn varnf dsid vid vlab i macrovars scanvar vlength;


%let macrovars=dsin dsout varc varn varnf;
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

data _null_;
	if cexist("work.formats.&varnf.format")=0 then do;
		put "WARNING: The format: &varnf specified for the numeric variable does not exist.";
	end;
run;

%let dsid=%sysfunc(open(&dsin));
%let vid=%sysfunc(varnum(&dsid,&varn));
%let vlab=%sysfunc(varlabel(&dsid,&vid));
%let rc=%sysfunc(close(&dsid));

data &dsout;
	set &dsin;
	attrib &varc length=$&vlength;
	&varc=strip(put(&varn,&varnf));
	label &varc="%sysfunc(strip(&vlab))";
run;

%exit: ; 

%mend num_to_char;
