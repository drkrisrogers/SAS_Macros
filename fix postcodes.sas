
if (postcode ge '1000' and postcode le '2599' ) or
	(postcode ge '2620' and postcode le '2899' ) or
	(postcode ge '2921' and postcode le '2999' ) then state='NSW';
if 	(postcode ge '3000' and postcode le '3999' ) or
	(postcode ge '8000' and postcode le '8999' ) then state='Vic';
if (postcode ge '4000' and postcode le '4999' ) or
	(postcode ge '9000' and postcode le '9999' ) then state='Qld';
if 	(postcode ge '5000' and postcode le '5999' ) then state='SA';
if 	(postcode ge '6000' and postcode le '6999' ) then state='WA';
if	(postcode ge '7000' and postcode le '7999' ) then state='Tas';
if 	(postcode ge '0200' and postcode le '0299' ) or
	(postcode ge '2600' and postcode le '2619' ) or
	(postcode ge '2900' and postcode le '2920' ) then state='ACT';
if (postcode ge '0800' and postcode le '0999' ) then state='NT';





