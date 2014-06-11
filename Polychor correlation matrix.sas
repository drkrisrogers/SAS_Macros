%macro polychor(
       version,
       data=_last_,
       var=_all_,
       out=_plcorr,
       type=corr,
       id=_ID_,
       order=,
       converge=,
       maxiter=,
       printlevels=yes
       );

%let notesopt = %sysfunc(getoption(notes));
options nonotes;
%let _version=1.7;
%if &version ne %then %put &sysmacroname macro Version &_version;

/* Check for newer version */
 %if %sysevalf(&sysver >= 7) %then %do;
  filename _ver url 'http://ftp.sas.com/techsup/download/stat/versions.dat';
  data _null_;
    infile _ver;
    input name:$15. ver;
    if upcase(name)="&sysmacroname" then call symput("_newver",ver);
    run;
  %if &syserr ne 0 %then
    %put &sysmacroname: Unable to check for newer version;
  %else %if %sysevalf(&_newver > &_version) %then %do;
    %put &sysmacroname: A newer version of the &sysmacroname macro is available.;
    %put %str(         ) You can get the newer version at this location:;
    %put %str(         ) http://support.sas.com/ctx/samples/index.jsp;
  %end;
 %end;

%if &data=_last_ %then %let data=&syslast;

/* Verify that TYPE=CORR or DISTANCE */
%if %upcase(&type) ne CORR and %upcase(&type) ne DISTANCE %then %do;
  %put POLYCHOR: TYPE= must be CORR or DISTANCE.;
  %goto exit;
%end;

/* Verify ORDER= value */
%if  %upcase(&order) ne %str()
 and %upcase(&order) ne DATA
 and %upcase(&order) ne FORMATTED 
 and %upcase(&order) ne INTERNAL
 and %upcase(&order) ne FREQ
 %then %do;
  %put POLYCHOR: ORDER= must be DATA, FORMATTED, INTERNAL or FREQ.;
  %goto exit;
%end;

/* Assign each variable to macro variable _Vxxx and total number of 
   variables to macro variable _P
*/
%let _i=1; %let _p=0;
%if %sysfunc(exist(&data)) %then %let dsid=%sysfunc(open(&data));
%else %do;
  %put ERROR: Data set &data does not exist. Terminating;
  %goto exit;
%end;
%if &dsid %then %do;
  %let _token=%scan(&var,&_i);
  %do %while ( &_token ne %str() );

    %if %upcase(&_token)=_ALL_ %then 
    %do _j=1 %to %sysfunc(attrn(&dsid,NVARS));
      %let _p=%eval(&_p+1);
      %let _v&_p = %sysfunc(varname(&dsid,&_j));
    %end;

    %else %if %upcase(&_token)=_NUMERIC_ %then 
    %do _j=1 %to %sysfunc(attrn(&dsid,NVARS));
      %if %sysfunc(vartype(&dsid,&_j))=N %then %do;
        %let _p=%eval(&_p+1);
        %let _v&_p = %sysfunc(varname(&dsid,&_j));
      %end;
    %end;

    %else %if %upcase(&_token)=_CHAR_ or %upcase(&_token)=_CHARACTER_ %then 
    %do _j=1 %to %sysfunc(attrn(&dsid,NVARS));
      %if %sysfunc(vartype(&dsid,&_j))=C %then %do;
        %let _p=%eval(&_p+1);
        %let _v&_p = %sysfunc(varname(&dsid,&_j));
      %end;
    %end;

    %else %do;
      %if %sysfunc(varnum(&dsid,&_token)) ne 0 %then %do;
        %let _p=%eval(&_p+1);
        %let _v&_p = &_token;
      %end;
      %else %do;
        %put ERROR: Variable &_token not found.  Terminating.;
        %goto exit;
      %end;
    %end;

    %let _i=%eval(&_i+1);
    %let _token=%scan(&var,&_i);
  %end;
  %let rc=%sysfunc(close(&dsid));
%end;
%else %do;
  %put ERROR: Could not open DATA= data set.  Terminating.;
  %goto exit;
%end;

%let noconv=0;
%do _i=1 %to &_p;
%do _j=&_i+1 %to &_p;
  proc datasets lib=work nolist; 
    delete _tmp; 
    run; quit;
  proc freq data=&data 
  %if &order ne %then order=&order;
  noprint;
    tables &&_v&_i * &&_v&_j / plcorr
    %if &converge ne %then converge=&converge;
    %if &maxiter  ne %then maxiter=&maxiter;
    ;
    output out=_tmp plcorr;
    run;
  %if %sysfunc(exist(_tmp)) ne 1 %then %do;
     %put POLYCHOR: Polychoric correlation could not be computed for variables
&&_v&_i and &&_v&_j%str(.);
     %let p&_i._&_j=.;
     %goto next;
  %end;
  data _null_;
    set _tmp;
    if _plcorr_=. then do;
      call symput('noconv','1');
      put "POLYCHOR: Polychoric correlation computations did not converge"
          " for variables";
      _vars=compbl("&&_v&_i and &&_v&_j.");
      put "          " _vars;
    end;
    value=    %if %upcase(&type)=CORR %then _plcorr_;
              %if %upcase(&type)=DISTANCE %then 1-_plcorr_**2;
    ;
    call symput("p&_i._&_j" , value);
    run;
 %next:
%end;
%end;
%if &noconv=1 %then %do;
  %put POLYCHOR: Some correlations were not estimated and were set to missing.;
  %put %str(          )You can try to estimate the missing correlations by using;
  %put %str(          )the CONVERGE= and/or MAXITER= options.  See the POLYCHOR;
  %put %str(          )macro description for details.;
%end;

data &out;
  %if %upcase(&type)=CORR %then %do;
    _TYPE_='CORR';
    length _NAME_
     %if &sysver >= 7 %then %str($32.;); %else %str($8.;);
  %end;

  /* Create matrix */
  array _x{*}     %do i=1 %to &_p;
                     &&_v&i
                  %end;
    ;
  do _i=1 to dim(_x);
    do _j=1 to _i;

      /* Set diagonal values */
      if _i=_j then _x{_j}=   %if %upcase(&type)=CORR     %then   1;
                              %if %upcase(&type)=DISTANCE %then   0;
      ;

      /* Set lower triangular values */
      else
      _x{_j}=symget("p"||trim(left(put(_j,4.)))||"_"||trim(left(put(_i,4.))));
    end;

    /* Create _NAME_ variable for CORR data sets */
    %if %upcase(&type)=CORR %then
      %str( _NAME_=symget("_v"||trim(left(put(_i,4.)))); );
    drop _i _j;
    output;
  end;
  run;

  /* Set data set type if distance and add ID var */
  %if %upcase(&type)=DISTANCE %then %do;
    data &out(type=distance);
      length &id $ 32;
      set &out;
      &id=symget(cats('_v',_n_)); 
      run;
  %end;

/* Add _TYPE_=MEAN, STD and N observations to CORR data sets */
%let charvars=;
%if %upcase(&type)=CORR %then %do;
  /* Don't run SUMMARY on character variables */
  %let nnumvar=0; 
  %let dsid=%sysfunc(open(&data));
  %if &dsid %then %do _i=1 %to &_p;
     %if %sysfunc(vartype(&dsid, %sysfunc(varnum(&dsid,&&_v&_i)) ))=N %then 
         %let nnumvar=%eval(&nnumvar+1);
     %if %sysfunc(vartype(&dsid, %sysfunc(varnum(&dsid,&&_v&_i)) ))=C %then
         %let charvars=&charvars &&_v&_i;
  %end;    
  %let rc=%sysfunc(close(&dsid));
  %if &nnumvar ne 0 %then %do;
    proc summary data=&data(keep=&var);
      var _numeric_;
      output out=_simple (drop=_type_ _freq_ rename=(_stat_=_TYPE_));
      run;
  %end;
  %else %do;
    data _simple;
      length _TYPE_ $ 8;
      _TYPE_='N'; output;
      _TYPE_='MEAN'; output;
      _TYPE_='STD'; output;
      run;
  %end;

  /* Add N for character variables */
  %if &charvars ne %then %do;
    ods exclude all;
    ods output onewayfreqs=_charn;
    proc freq data=&data; 
      table &charvars;
      run;
    ods select all;
    proc sort data=_charn; by table; run;
    data _charn; 
      set _charn; 
      by table; if last.table;
      vname=scan(table,2);
      keep vname cumfrequency;
      run;
    proc transpose data=_charn out=_charn(drop=_name_ _label_);
      var cumfrequency; id vname;
      run;
    data _charn; set _charn;
      _TYPE_='N';
      run;
    data _simple; 
      merge _simple _charn; 
      run;
  %end;

  data &out (type=corr);
    set _simple (where=(_type_ in ('MEAN','STD','N'))) &out;
    run;
%end;

/* Print Character Variable Levels table */
%if %upcase(%substr(&printlevels,1,1))=Y and &charvars ne %then %do;
  proc freq data=&data
  %if &order ne %then order=&order;
  ; 
    tables _character_; 
    title2 "Character Variable Levels";
    run;
  title2;
%end;

%if &syserr=0 %then
%if %upcase(&type)=CORR %then %do;
  %put;
  %put POLYCHOR: Polychoric correlation matrix was output to data set %upcase(&out).;
  %put;
%end;
%else %do;
  %put;
  %put POLYCHOR: Distance matrix based on polychoric correlations was output;
  %put %str(          )to data set %upcase(&out).;
  %put;
%end;

%exit:
options &notesopt;
%mend polychor;



%macro tetchor(inds=,outds=,vars=);
%local inds outds vars varcount;

%let varcount=%sysfunc(countw(&vars));
 
ods output Measures=work.measures (where=(statistic='Tetrachoric Correlation'));
 proc freq data=&inds ;
%do i=1 %to &varcount;
	%do j=1 %to &varcount;
		%if (&i lt &j) %then %do;
	    	tables %qscan(&vars,&i) * %qscan(&vars,&j) / plcorr;
		%end;
	%end;
%end;
run;

*create a quoted list of variable names;
%let varlist=;
%do i=1 %to &varcount;
	%let varlist=&varlist "%qscan(&vars,&i)";
%end;
 
data measures (keep= var1 var2 value order1 order2);
	attrib var1 length=$12 var2 length=$12;
	set measures;
	
	array varnames{&varcount} $12 _temporary_ (&varlist);
 	var1=scan(table,2);
	var2=scan(table,3);

	do i=1 to dim(varnames);
		if var1=varnames{i} then order1=i;
		if var2=varnames{i} then order2=i;
	end;
run;

 
proc sort data=work.measures;
	by order1 order2;
run;

proc transpose data=work.measures out=work.measuresm ;
	by var1 notsorted;
	var value;
	id var2;
run;

%let firstvar=%qscan(&vars,1);
%let seclasvar=%qscan(&vars,%eval(&varcount-1));
%let lastvar=%qscan(&vars,&varcount);

data &outds (drop=_name_ order i);
	attrib var1 label='Variable' &firstvar length=8;
	set work.measuresm end=last;
 	order+1;
	array varnames{&varcount} $12 _temporary_ (&varlist);
	array vars{&varcount} &vars;

    do i=1 to dim(vars);
		if i=order then vars{i}=1;
	end;
	output;
	if last then do;
		var1="&lastvar";
		&seclasvar=.;
		&lastvar=1;
		output;
	end;
run;


proc sql noprint;
	drop table work.measures, work.measuresm;
quit;
%mend tetchor;

%tetchor(inds=work._45up,outds=work.food_corr,vars=noeggs nodairy nocheese noeatcream nosugar nowheat nomeat nochicken nopork noredmeat noseafood nofish);


