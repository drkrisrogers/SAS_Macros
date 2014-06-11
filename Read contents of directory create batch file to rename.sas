
%let indir=G:\Programs\45 and Up Study\9 Data within study\DVA\Text;

filename DIRLIST pipe  %unquote(%nrbquote('dir "&indir" ')) ;  
data dirlist ;                                               
	infile dirlist lrecl=200 truncover;                          
	input line $200.;                                            
	length file_name $ 100;    
 
	file_name="&indir"||"\"||scan(line,-1," ");   
	if scan(file_name,-1,".") ne 'txt' then delete; 
	keep file_name;   
run;

data WORK.text                                    ;
	infile 'G:\Programs\45 and Up Study\9 Data within study\DVA\Text\TEXT_ALC_DAYS_PW.txt'   delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=1 ;
   	informat line $1500. ;
   	format line $1500. ;
	input line $ ;
run;

data work._text (drop=lastvalue );
	set work.text;
	order+1;
	retain keep_flag table_flag lastvalue;
	
	if line in('%title' '%subtitle' '%paragraph' '%table') then keep_flag=1;
	if line = '%table' then table_flag=1;
	if table_flag=1 and line='%caption' then do; keep_flag=1; table_flag=0; end;
	if missing(line)=1 or line='Internal cross references' then keep_flag=0;
run;

proc sort data=work._text;
	by descending order;
run;

data work._text;
	set work._text;
	retain lastvalue;
	
	if keep_flag=1 and lastvalue='Internal cross references' then keep_flag=0;
	if keep_flag=1 and lastvalue='%end' then keep_flag=0;
	lastvalue=line;

data work._text;
	set work.text (keep=line);
	output;
	if line='%end' then do; call missing(line); output; end;

run;
 


%macro accelfile (indir=,outdir=);
%local indir outdir max read dset fname total active accel i pipedir id time;

filename DIRLIST pipe  %unquote(%nrbquote('dir "&indir" ')) ; 
; 
 
data dirlist ;                                               
	infile dirlist lrecl=200 truncover;                          
	input line $200.;                                            
	length file_name $ 100;    
 
	file_name="&indir"||"\"||scan(line,-1," ");   
	if scan(file_name,-1,".") ne 'xls' then delete; 
	keep file_name;   
run;

                                                             
data _null_;                                                 
	set dirlist end=end;  
	count+1;    
	
	if end then call symput('max',count);                        
run;

proc sql noprint;
	select file_name into :filelist separated by '_'
	from work.dirlist;
quit;
 
%do i=1 %to &max;
	%let fname=%scan(&filelist,&i,"_");
 

  

	proc sql noprint;
		drop table w ;
	quit;
%end;


proc sql noprint;
drop table work.dirlist;
quit;

%mend accelfile;