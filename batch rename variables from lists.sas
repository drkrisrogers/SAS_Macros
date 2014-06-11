
%macro batch_rename (varlist=,newvars=);
	%local varlist newvars i;

 	%do i=1 %to %sysfunc(countw(&varlist));
		rename %qscan(&varlist,&i) = %qscan(&newvars,&i);
	%end;

 %mend batch_rename;

 %macro batch_rename_suf (varlist=,suf=);
%local varlist suf k;
%let k=1;
%let old = %scan(&varlist, &k);
   %do %while("&old" NE "");
    rename &old = &old.&suf;
  %let k = %eval(&k + 1);
    %let old = %scan(&varlist, &k);
%end;
%mend batch_rename_suf;

%macro batch_conv_suf (varlist=,suf=);
%local varlist suf k;
%let k=1;
%let old = %scan(&varlist, &k);
%do %while("&old" NE "");
    &old = input(trim(left(&old.&suf)),8.);
    %let k = %eval(&k + 1);
    %let old = %scan(&varlist, &k);
%end;
%mend batch_conv_suf;

%macro suf_list (varlist=,suf=);
%local varlist suf k;
%let k=1;
%let old = %scan(&varlist, &k);
%do %while("&old" NE "");
   &old.&suf 
    %let k = %eval(&k + 1);
    %let old = %scan(&varlist, &k);
%end;
%mend suf_list;
