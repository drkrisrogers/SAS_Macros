%macro add_predictive(data=, y=, p_old=, p_new= , nripoints=%str(),hoslemgrp=10) ; 
/*--- 
this macro attempts to quantify the added predictive ability of a covariate(s) 
in logistic regression based off of the statistics in: M. J. Pencina ET AL. Statistics 
in Medicine (2008 27(2):157-72). Statistics returned with be: C-statistics (for 9.2 users), 
IDI (INTEGRATED DISCRIMINATION IMPROVEMENT), NRI (net reclassification index) 
for both Category-Free and User defined groups, and Hosmer Lemeshow GOF test 
with associated pvalues and z scores. 
Parameters (* = required) 
------------------------- 
data* Specifies the SAS dataset 
y* Response variable (Outcome must be 0/1) 
p_old* Predicted Probability of an Event using Initial Model 
p_new* Predicted Probability of an Event using New Model 
nripoints Groups for User defined classification (Optional), 
 Example 3 groups: (<.06, .06-.2, >.2) then nripoints=.06 .2 
hoslemgrp # of groups for the Hosmer Lemeshow test (default 10) 
Author: Kevin Kennedy and Michael Pencina 
Date: May 26, 2010 
---*/


	options nonotes nodate nonumber; 
	ods select none; 

	%local start end ; 

	%let start=%sysfunc(datetime()); 

	proc format; 
		value pval 0-.0001='<.0001'; 
	run; 

	/******Step 1: C-Statistics******/
	/********************************/
	%if %sysevalf(&sysver >= 9.2) %then %do; 
		%put ********Running AUC Analysis************; 

		 proc logistic data=&data descending; 
			 model &y=&p_old &p_new; 
			 roc 'first' &p_old; 
			 roc 'second' &p_new; 
			 roccontrast reference('first')/estimate e; 
			 ods output ROCAssociation=rocass ROCContrastEstimate=rocdiff; 
		 run; 

		 proc sql noprint; 
			 select estimate, StdErr, lowercl, uppercl, (ProbChiSq*100) as pval 
			 into :rocdiff, :rocdiff_stderr, :rocdiff_low, :rocdiff_up, :rocp 
			 from rocdiff 
			 where find(contrast,'second'); 
		 quit; 

		 data _null_; 
			 set rocass; 
			 if ROCModel='first' then do; 
				 call symputx('c_old',Area); 
			 end; 
			 if ROCModel='second' then do; 
				 call symputx('c_new',Area); 
			 end; 
		 run; 

		 data cstat; 
			 cstat_old=&c_old; label cstat_old='Model1 AUC'; 
			 cstat_new=&c_new; label cstat_new='Model2 AUC'; 
			 cstat_diff=&rocdiff; label cstat_diff='Difference in AUC'; 
			 cstat_stderr=&rocdiff_stderr; label cstat_stderr='Standard Error of Difference in AUC'; 
			 cstat_low=&rocdiff_low; label cstat_low='Difference in AUC Lower 95% CI';  
			 cstat_up=&rocdiff_up; label cstat_up='Difference in ACU Upper 95% CI'; 
			 cstat_ci='('!!trim(left(cstat_low))!!','!!trim(left(cstat_up))!!')'; 
			 label cstat_ci='95% CI for Difference in AUC'; 
			 cstat_pval=&rocp/100; label cstat_pval='P-value for AUC Difference'; 
			 format cstat_pval pval.; 
		 run; 
	%end; 
	%if %sysevalf(&sysver < 9.2) %then %do; 
		options notes ; 
		%put *********************; 
		%put NOTE: You are running a Pre 9.2 version of SAS; 
		%put NOTE: Go to SAS website to get example of ROC Macro for AUC Comps; 
		%put NOTE: http://support.sas.com/kb/25/017.html; 
		%put *********************; 
		%put; 
		options nonotes ; 
	%end; 

	/******************************/
	/*****End step 1***************/
	/******************************/
	/******Step 2: IDI***************/
	%put ********Running IDI Analysis************; 

	proc sql noprint; 
		create table idinri as select &y,&p_old, &p_new, (&p_new-&p_old) as pdiff 
		from &data 
		where &p_old^=. and &p_new^=.
		order by &y; 
	quit; 

	proc sql noprint; /*define mean probabilities for old and new model and event and nonevent*/
		select count(*),avg(&p_old), avg(&p_new),stderr(pdiff) into 
		:num_event, :p_event_old, :p_event_new,:eventstderr
		from idinri 
		where &y=1 ; 
		select count(*),avg(&p_old), avg(&p_new),stderr(pdiff) into 
		:num_nonevent, :p_nonevent_old, :p_nonevent_new ,:noneventstderr 
		from idinri 
		where &y=0; 
	quit; 

	data fin(drop=slope_noadd slope_add); 
		pen=&p_event_new; label pen='Mean Probability for Events: Model2'; 
		peo=&p_event_old; label peo='Mean Probability for Events: Model1'; 
		pnen=&p_nonevent_new; label pnen='Mean Probability for NonEvents: Model2'; 
		pneo=&p_nonevent_old; label pneo='Mean Probability for NonEvents: Model1'; 
		idi=(&p_event_new-&p_nonevent_new)-(&p_event_old-&p_nonevent_old); 
		label idi='Integrated Discrimination Improvement'; 
		idi_stderr=sqrt((&eventstderr**2)+(&noneventstderr**2)); 
		label idi_stderr='IDI Standard Error'; 
		idi_lowci=round(idi-1.96*idi_stderr,.0001); 
		idi_upci=round(idi+1.96*idi_stderr,.0001); 
		idi_ci='('!!trim(left(idi_lowci))!!','!!trim(left(idi_upci))!!')'; 
		label idi_ci='IDI 95% CI'; 
		z_idi=abs(idi/(sqrt((&eventstderr**2)+(&noneventstderr**2)))); 
		label z_idi='Z-value for IDI'; 
		pvalue_idi=2*(1-PROBNORM(abs(z_idi))); label pvalue_idi='P-value for IDI'; 
		change_event=&p_event_new-&p_event_old; 
		label change_event='Probability change for Events'; 
		change_nonevent=&p_nonevent_new-&p_nonevent_old; 
		label change_nonevent='Probability change for Nonevents'; 
		slope_noadd=&p_event_old-&p_nonevent_old; 
		slope_add=&p_event_new-&p_nonevent_new; 
		relative_idi=slope_add/slope_noadd-1; label relative_idi='Relative IDI'; 
		format pvalue_idi pval.; 
	run; 

	/************step 3 NRI analysis*******/

	%put ********Running NRI Analysis************; 
	data nri_inf; 
	set idinri; 
	if &y=1 then do; 
		down_event=(pdiff<0);up_event=(pdiff>0);down_nonevent=0;up_nonevent=0; 
	end; 
	if &y=0 then do; 
		down_nonevent=(pdiff<0);up_nonevent=(pdiff>0);down_event=0;up_event=0; 
	end; 
	run; 

	proc sql; 
	select sum(up_nonevent), sum(down_nonevent), sum(up_event),sum(down_event) 
	into :num_nonevent_up_user, :num_nonevent_down_user, :num_event_up_user, :num_event_down_user 
	from nri_inf 
	quit; 

	/* Category-Free Groups */

	data nri1; 
		group="Category-Free NRI"; 
		p_up_event=&num_event_up_user/&num_event; 
		p_down_event=&num_event_down_user/&num_event; 
		p_up_nonevent=&num_nonevent_up_user/&num_nonevent; 
		p_down_nonevent=&num_nonevent_down_user/&num_nonevent; 
		nri=(p_up_event-p_down_event)-(p_up_nonevent-p_down_nonevent); 
		nri_stderr=sqrt(((&num_event_up_user+&num_event_down_user)/&num_event**2-(&num_event_up_user-
		&num_event_down_user)**2/&num_event**3)+ 
		 ((&num_nonevent_down_user+&num_nonevent_up_user)/&num_nonevent**2-
		(&num_nonevent_down_user-&num_nonevent_up_user)**2/&num_nonevent**3)); 
		low_nrici=round(nri-1.96*nri_stderr,.0001); 
		up_nrici=round(nri+1.96*nri_stderr,.0001); 
		nri_ci='('!!trim(left(low_nrici))!!','!!trim(left(up_nrici))!!')'; 
		z_nri=nri/sqrt(((p_up_event+p_down_event)/&num_event) 
		+((p_up_nonevent+p_down_nonevent)/&num_nonevent)) ;
		pvalue_nri=2*(1-PROBNORM(abs(z_nri))); 
		event_correct_reclass=p_up_event-p_down_event; 
		nonevent_correct_reclass=p_down_nonevent-p_up_nonevent; 
		z_event=event_correct_reclass/sqrt((p_up_event+p_down_event)/&num_event); 
		pvalue_event=2*(1-probnorm(abs(z_event))); 
		z_nonevent=nonevent_correct_reclass/sqrt((p_up_nonevent+p_down_nonevent)/&num_nonevent); 
		pvalue_nonevent=2*(1-probnorm(abs(z_nonevent))); 
		format pvalue_nri pvalue_event pvalue_nonevent pval. event_correct_reclass 
		nonevent_correct_reclass percent.; 
		label nri='Net Reclassification Improvement'
		 nri_stderr='NRI Standard Error'
		 low_nrici='NRI lower 95% CI'
		 up_nrici='NRI upper 95% CI'
		 nri_ci='NRI 95% CI'
		 z_nri='Z-Value for NRI'
		 pvalue_nri='NRI P-Value'
		 pvalue_event='Event P-Value'
		 pvalue_nonevent='Non-Event P-Value'
		 event_correct_reclass='% of Events correctly reclassified'
		 nonevent_correct_reclass='% of Nonevents correctly reclassified'; 
	run; 

	/*User Defined NRI*/

	%if &nripoints^=%str() %then %do; 

		/*words macro*/

		%macro words(list,delim=%str( )); 
			%local count; 
			%let count=0; 
			%do %while(%qscan(%bquote(&list),&count+1,%str(&delim)) ne %str()); 
				%let count=%eval(&count+1); 
			%end; 
			 &count 
		%mend words; 

		%let numgroups=%eval(%words(&nripoints)+1); /*figure out how many ordinal groups*/

		proc format ; 
			value group 
			1 = "0 to %scan(&nripoints,1,%str( ))"
			%do i=2 %to %eval(&numgroups-1); 
			%let j=%eval(&i-1); 
		 		&i="%scan(&nripoints,&j,%str( )) to %scan(&nripoints,&i,%str( ))" 
			%end; 
			%let j=%eval(&numgroups-1); 
	 		&numgroups="%scan(&nripoints,&j,%str( )) to 1"; 
		run; 

		data idinri; 
			set idinri; 
			/*define first ordinal group for pre and post*/
			if 0<=&p_old<=%scan(&nripoints,1,%str( )) then group_pre=1; 
			if 0<=&p_new<=%scan(&nripoints,1,%str( )) then group_post=1; 
			%let i=1; 
			%do %until(&i>%eval(&numgroups-1));  
			if %scan(&nripoints,&i,%str( ))<&p_old then do; 
				group_pre=&i+1; 
			end; 
			if %scan(&nripoints,&i,%str( ))<&p_new then do; 
				group_post=&i+1; 
			end; 

			%let i=%eval(&i+1); 
			%end; 
			if &y=0 then do; 
				up_nonevent=(group_post>group_pre); 
				down_nonevent=(group_post<group_pre); 
				down_event=0; up_event=0; 
			end; 
			if &y=1 then do; 
				up_event=(group_post>group_pre); 
				down_event=(group_post<group_pre); 
				down_nonevent=0; up_nonevent=0; 
			end; 
			format group_pre group_post group.; 
		run; 

		proc sql; 
			select sum(up_nonevent), sum(down_nonevent), sum(up_event),sum(down_event),avg(&y) 
			into :num_nonevent_up_user, :num_nonevent_down_user, :num_event_up_user, 
			:num_event_down_user, :eventrate 
			from idinri ;
		 quit; 

		data nri2; 
			 group='User Category NRI'; 
			 p_up_event=&num_event_up_user/&num_event; 
			 p_down_event=&num_event_down_user/&num_event; 
			 p_up_nonevent=&num_nonevent_up_user/&num_nonevent;
			 p_down_nonevent=&num_nonevent_down_user/&num_nonevent; 
			 nri=(p_up_event-p_down_event)-(p_up_nonevent-p_down_nonevent); 
			 nri_stderr=sqrt(((&num_event_up_user+&num_event_down_user)/&num_event**2-
			(&num_event_up_user-&num_event_down_user)**2/&num_event**3)+ 
			 ((&num_nonevent_down_user+&num_nonevent_up_user)/&num_nonevent**2-
			(&num_nonevent_down_user-&num_nonevent_up_user)**2/&num_nonevent**3)); 
			 low_nrici=round(nri-1.96*nri_stderr,.0001); 
			 up_nrici=round(nri+1.96*nri_stderr,.0001); 
			 nri_ci='('!!trim(left(low_nrici))!!','!!trim(left(up_nrici))!!')'; 
			 z_nri=nri/sqrt(((p_up_event+p_down_event)/&num_event) 
			+((p_up_nonevent+p_down_nonevent)/&num_nonevent)) ;
			 pvalue_nri=2*(1-PROBNORM(abs(z_nri))); 
			 event_correct_reclass=p_up_event-p_down_event; 
			 nonevent_correct_reclass=p_down_nonevent-p_up_nonevent; 
			 z_event=event_correct_reclass/sqrt((p_up_event+p_down_event)/&num_event); 
			 pvalue_event=2*(1-probnorm(abs(z_event))); 
			 z_nonevent=nonevent_correct_reclass/sqrt((p_up_nonevent+p_down_nonevent)/&num_nonevent); 
			 pvalue_nonevent=2*(1-probnorm(abs(z_nonevent))); 
			format pvalue_nri pval.; 
		run; 

		data nri1; 
			set nri1 nri2; 
		run; 
	%end; 
	/**************/
	/*step 4 gof */
	/**************/

	%hoslem(data=idinri,pred=&p_old,y=&y,ngro=&hoslemgrp,out=m1,print=F); 
	%hoslem(data=idinri,pred=&p_new,y=&y,ngro=&hoslemgrp,out=m2,print=F); 

	data hoslem(drop=cnt); 
		retain model; 
		set m1 m2; 
		cnt+1; 
		if cnt=1 then model='Model1'; 
		else model='Model2'; 
	run; 

	ods select all; 
	/*output for cstat*/
	%if %sysevalf(&sysver >= 9.2) %then %do; 
		proc print data=cstat label noobs; 
		title1 "Evaluating added predictive ability of model2"; 
		title2 'AUC Analysis';run;  
	%END; 

	/*output for IDI*/
	proc print data=fin label noobs; 
		title1 "Evaluating added predictive ability of model2"; 
		title2 'IDI Analysis'; 
		var idi idi_stderr z_idi pvalue_idi idi_ci 
		pen peo pnen pneo change_event change_nonevent relative_idi; 
	run; 

	/*output for NRI*/
	proc print data=nri1 label noobs; 
		title1 "Evaluating added predictive ability of model2"; 
		title2 'NRI Analysis'; 
		var group nri nri_stderr z_nri pvalue_nri nri_ci event_correct_reclass pvalue_event 
		nonevent_correct_reclass pvalue_nonevent; 
	run; 

	%if &nripoints^=%str() %then %do; 
		proc freq data=idinri; 
			where &y=0; 
			title 'NRI Table for Non-Events'; 
			tables group_pre*group_post/nopercent nocol; 
		run; 

		proc freq data=idinri; 
			where &y=1; 
			title 'NRI Table for Events'; 
			tables group_pre*group_post/nopercent nocol; 
		run; 
	%end; 
	/*print HL gof*/
	proc print data=hoslem noobs label; 
		title "Hosmer Lemeshow Test with %sysevalf(&hoslemgrp-2) df"; 
	run; 

	proc datasets library=work nolist; 
		delete fin idinri nri1 nri2 nri_inf stderr; 
	quit; 

	options notes; 
	%put NOTE: Macro %nrstr(%%)add_predictive completed.; 
	%let end=%sysfunc(datetime()); 
	%let runtime=%sysfunc(round(%sysevalf(&end-&start))); 
	%put NOTE: Macro Real Run Time=&runtime seconds; 
	title; 
%mend add_predictive;
