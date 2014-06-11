
%macro batch_label(varlist=,labels=);
	%local varlist labels i;

	%if %sysfunc(countw(&varlist))  ne %sysfunc(countw(&labels,^)) %then %do; 
		%put ERROR: Number of variables does not match number of labels;
		%goto terminate;
	%end;

	%do i=1 %to %sysfunc(countw(&varlist));
		label %qscan(&varlist,&i) = "%qscan(&labels,&i,^)";
	%end;

	%terminate:;
%mend batch_label;
