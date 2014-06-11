*Creat a quoted list of variables in a macro variable;
proc sql noprint;
select quote(trim(left(name))) into :varn separated by " "
	from dictionary.columns
	where libname="WORK" and memname="CT" 
	and name not in('Table' "&classvar" '_TYPE_' '_TABLE_' 'Frequency' 'ColPercent' 'Missing');
quit;
