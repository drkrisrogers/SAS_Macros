* Created by Kris Rogers;
* This macro will create a table in (as a SAS data table) which contains summary data of categorical variables
  according to a classicication variable (ie. a binary/categorical exposure variable,);
  
*Dependencies: you need to run batch label variables from lists.sas This should be in the SAS_Macros repository;


%macro sum_table(datain=,dataout=,classvar=,vars=,all=no);
%local datain vars classvar numlevels varnames fmtnames varn space varname varf all keepvals;

ods output CrossTabFreqs=work.ct;
proc freq data=&datain;
	table (&vars)*&classvar /norow nopercent;
run;

proc sql noprint;
	select name into :varnames separated by ' '
	from dictionary.columns
	where libname="WORK" and memname="CT" 
	and name not in('Table' "&classvar" '_TYPE_' '_TABLE_' 'Frequency' 'ColPercent' 'Missing');
	select quote(trim(left(name))) into :varn separated by " "
	from dictionary.columns
	where libname="WORK" and memname="CT" 
	and name not in('Table' "&classvar" '_TYPE_' '_TABLE_' 'Frequency' 'ColPercent' 'Missing');
	select quote(trim(left(label))) into :varl separated by " "
	from dictionary.columns
	where libname="WORK" and memname="CT" 
	and name not in('Table' "&classvar" '_TYPE_' '_TABLE_' 'Frequency' 'ColPercent' 'Missing');
 	select format into :varf from dictionary.columns where libname="WORK" and memname="CT" and name="&classvar";

quit;
 
 data work.ct (keep= value  Variable frequency &classvar level ColPercent Label where=(level is not missing and missing(&classvar) ne 1));
	set work.ct end=last;
	attrib   level length=$30   value length=$20;
	array levels{*} &varnames;
	array varnames{%sysfunc(countw(&varn))} $20 _temporary_ (&varn);
	array varlabel{%sysfunc(countw(&varn))} $40 _temporary_ (&varl);

 	do i=1 to dim(levels);
 
 		if missing(levels{i}) ne 1 then do;
			level=vvalue(levels{i});
			Variable=varnames{i};
			Label=varlabel{i};
		end;
	end;
	format colpercent 4.1;
	value=trim(left(cat(put(frequency,comma7.),' (',put(colpercent,4.1),'%)')));

run;

proc sql noprint;
	create table work.levelcount as select distinct(&classvar) from &datain;
	select  count(distinct(put(&classvar,&varf))) into:numlevels from &datain;
 	select distinct(&classvar) format=8. into:levels separated by ' ' from &datain where missing(&classvar) ne 1;
quit;

proc transpose data=work.ct out=work.ctval (where=(missing(_NAME_) ne 1)) prefix=val_  ;
	by level notsorted;
 	var  value  ;
	idlabel &classvar;
	copy label;
run;

 proc transpose data=work.ct out=work.ctl (where=(missing(_NAME_) ne 1 )) prefix=l_  ;
	by level notsorted;
	id &classvar ;
	var  value  ;
	idlabel &classvar;
	copy label;
run;

proc transpose data=work.ct out=work.ctfreq prefix=freq_;
	by level notsorted;
	var frequency;
run;	

proc sql noprint;
	select name into :vals separated by ' '	from dictionary.columns
	where libname="WORK" and memname="CTVAL" and name not in('level' '_NAME_' '_FREQ_' '_LABEL_' 'Label');
	select label into :labs separated by ' ^'	from dictionary.columns
	where libname="WORK" and memname="CTL" and name not in('level' '_NAME_' '_FREQ_' '_LABEL_' 'Label');
	select name into :freqs separated by '  '	from dictionary.columns
	where libname="WORK" and memname="CTFREQ" and name not in('level' '_NAME_' '_FREQ_' '_LABEL_' 'Label');
quit;

 
data work.ct;
	attrib label length=$40;
	merge work.ctval (drop=_NAME_ ) work.ctfreq (drop=_name_ _label_) end=last;
 	order=_n_;
	if last then call symput('obs',_n_);
run;


%if (&all=yes) %then %do;
	ods output OneWayFreqs=work.ow;
	proc freq data=_45upsummary;
		table (&vars)  /nocum;
	run;


	proc sql noprint;
		select name into :varnames separated by ' '
		from dictionary.columns
		where libname="WORK" and memname="OW" 
		and name not in('Table' 'Frequency' 'Percent') and name not contains "F_";
		select quote(trim(left(name))) into :varn separated by " "
		from dictionary.columns
		where libname="WORK" and memname="OW" 
		and name not in('Table' 'Frequency' 'Percent') and name not contains "F_";
		select quote(trim(left(label))) into :varl separated by " "
		from dictionary.columns
		where libname="WORK" and memname="OW" 
		and name not in('Table' 'Frequency' 'Percent') and name not contains "F_";
	quit;


 	data work.ow (keep= val_99  Variable  level  Label where=(level is not missing));
		set work.ow end=last;
		attrib   level length=$30   val_99 length=$20;
		array levels{*} &varnames;
		array varnames{%sysfunc(countw(&varn))} $20 _temporary_ (&varn);
		array varlabel{%sysfunc(countw(&varn))} $40 _temporary_ (&varl);

	 	do i=1 to dim(levels);
	 
	 		if missing(levels{i}) ne 1 then do;
				level=vvalue(levels{i});
				Variable=varnames{i};
				Label=varlabel{i};
			end;
		end;
		format percent 4.1;
		val_99=trim(left(cat(put(frequency,comma7.),' (',put(percent,4.1),'%)')));
		label val_99='All';
	run;

	data work.ct;
		merge work.ct
			  work.ow (keep=val_99);
	run;
	%let keepvals= &vals val_99;
	%let exlevels=%eval(&numlevels+1);
%end;
%else %do; %let keepvals=&vals; %let exlevels=&numlevels; %end;

proc sort data=work.ct;
	by label order;
run;

%let maxcount=count%sysfunc(trim(%sysfunc(left(&numlevels))));
 
data work.ct (keep=  &keepvals order label level );
	set work.ct end=last;
	by label ;
	array count{&numlevels} count1-&maxcount;
	array freq{&numlevels} &freqs;
	array vals{&numlevels} &vals ;
	array keepvals{&exlevels} &keepvals;
	retain count1-&maxcount;

	if first.label then do i=1 to dim(count);
		count{i}=0;
	end;

	do i=1 to dim(count);
		count{i}=count{i}+freq{i};
	end;
	label label='Variable' level='Value';
	if not first.label then label=' ';
	output;

	%batch_label(varlist=&vals,labels=&labs);

	if last.label then do;
		do i=1 to (dim(keepvals));
			call missing(keepvals{i},level,label);
		end;
		order=order+0.5;
		output;
	end;
	if last then do;
		order=%eval(1+&obs);
		Label='Total';
		do i=1 to dim(count);
			vals{i}=trim(left(count{i}));
		end;
		%if (&all=yes) %then %do;
			count_99=0;
			do i=1 to dim(vals); 
				count_99=count_99+input(vals{i},8.);
			end;
			val_99=trim(left(put(count_99,8.)));
 		%end;
		output;
	end;
run;

proc sort data=work.ct out=&dataout (drop=order);
	by order;
run;


proc sql noprint;
	drop table work.ct, work.ctfreq, work.ctl, work.ctval;
	%if (&all=yes) %then %do; drop table work.ow; %end;
quit;


%mend sum_table;



 


 
