
**********
Author: Kris Rogers 
Title: C-Index for large datasets
Date: October 2013
Purpose: This macro will efficiently calculate Harrels C-Index (ref: ) in SAS. This is inspired by a SAS macro
		 developed by Mithat Gonen from the SAS Institute: 
		(http://www.mskcc.org/sites/www.mskcc.org/files/node/11749/documents/sas-code-macros.txt).

		 This original macro is fine for smaller datasets and will work for large datasets if you are very patient.

		 The problem is that caluclating Harrel's C-Index requires a Cartesian join/product, so the resulting table
		 will be of the size n^2.  Fine if you have 500 observations - 500^2 (or 500**500 if you speak sas :)) 
         is a manageable (by SAS standards) 250000 rows. Not so good if you have 200,000. 

		 The trick to this macro is a combination of not producing a dataset (data _null_) and an 
		 esoteric data step 'set' option called 'point'. Point will open a dataset in memory - in this case for every 
	     observation in our output from phreg, we open the dataset again but keep it all in memory (and with
		 the data _null_ it is not be written either). At the end of each observation we only retain the info
		 we need (with the retain statements) and discard the rest and keep working. Pretty nifty.
Dependecies: No other macros, but you need these lines to work:
			
;
*************;



%macro cindex(datain=work.obs,timevar=time_weeks,censorvar=censor,outds=,idvar=ppn);
%local datain timevar censorvar idvar outds;

data work.evtset; 
	set &datain (keep=&idvar xb &timevar &censorvar); 
	rename &idvar=idn_j xb=y_j &timevar=x_j;
	where &censorvar=1; 
run;

data work.obs;
	set work.obs;
	rename &idvar=idn_i xb=y_i &timevar=x_i;
run;

data _null_;
	set work.obs (keep=idn_i y_i x_i) end=eof;
	retain nch 0 ndh 0 pairs 0;
	
	do i=1 to n;
		set work.evtset (keep=idn_j y_j x_j) point=i nobs=n;
		if idn_i ne idn_j then do;
			if (x_i<x_j and y_i>y_j) or (x_i>x_j and y_i<y_j) then nch+1; 
			else ndh+1; 
			pairs+1;
		end;
	end;
	if eof then do;
		call symput('ch',trim(left(nch))); 
		call symput('dh',trim(left(ndh))); 
		call symput('uspairs',trim(left(pairs))); 
	end;
run;

proc sql noprint;
	select count(idn_i) into :totobs
	from work.obs;
quit;

data &outds; 
	ch=input("&ch",12.0); 
	dh=input("&dh",12.0); 
	uspairs=input("&uspairs",12.0); 
	totobs=input("&totobs",10.0); 
	pc=ch/(totobs*(totobs-1)); 
	pd=dh/(totobs*(totobs-1)); 
	c_hat=pc/(pc+pd); 
	w=(2*1.96**2)/(totobs*(pc+pd)); 
	low_ci_w=((w+2*c_hat)/(2*(1+w)))-(sqrt((w**2+4*w*c_hat*(1-c_hat))/(2*(1+w)))); 
	upper_ci_w=((w+2*c_hat)/(2*(1+w)))+(sqrt((w**2+4*w*c_hat*(1-c_hat))/(2*(1+w)))); 
run; 
 
proc sql noprint;
	drop table  work.evtset, work.obs;
quit;


%mend cindex;
