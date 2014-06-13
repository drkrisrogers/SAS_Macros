***
Author: Kris Rogers
Date: 10/6/2014
Purpose: Develop a macro that sets up the environment variables of each work site. 
	     Eventually generalise this so this can be run for any project;

%macro set_libs(readonly=yes);
%local readonly;
%global ds_ccr macropath;

%if (&syssite=10003956) %then %do;
	libname CRD 'H:\CESR\Linked Colorectal Data\Data' access=readonly;
	libname lnkfmts 'G:\Projects\Anal cancer\SAS work' access=readonly;
	%let ds_ccr=Fullcohort_analysis;
	%let macropath=G:\Github\SAS_Macros;
%end;
%else %if (&syssite=10005349) %then %do;
	libname CRD 'W:\Colorectal\Linked data\Data files' access=readonly;
	libname lnkfmts 'W:\Colorectal\Linked data\Formats' access=readonly;
	%let ds_ccr=Fullcohort_analysis;
	%let macropath=H:\Repository\GitHub\CESR\SAS_Macros;
%end;

%mend set_libs;
