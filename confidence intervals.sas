
%macro binomialci (n=,totaln=,);
%local n totaln;
cat(round(100*&n/&totaln,.1),"% (",round(100*lci(&n,&totaln),.1)," - ",round(100*uci(&n,&totaln),.1),")");

%mend;

%macro normci (est=,se=,);
%local est se;
cat(round(&est,.01)," (",round(&est-(1.96*&se),.01)," - ",round(&est+(1.96*&se),0.01),")");

%mend;


proc fcmp outlib=sasuser.funcs.trial ;
	function lci(n,totaln);
		p=n/totaln;
		se=sqrt(((n/totaln)*(1-n/totaln))/totaln );
		lci=p-1.96*se;
		return(lci);
	endsub;
	function uci(n,totaln);
		p=n/totaln;
		se=sqrt(((n/totaln)*(1-n/totaln))/totaln );
		uci=p+1.96*se;
		return(uci);
	endsub;
quit;

