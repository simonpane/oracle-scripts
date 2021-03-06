#!/bin/bash
# Fred Denis - denis@pythian.com - January 12th 2016
# Quickly show a status of all running instances accross a 12c cluster
#

      TMP=/tmp/status$$.tmp						# A tempfile
DBMACHINE=/opt/oracle.SupportTools/onecommand/databasemachine.xml	# File where we should find the Exadata model as oracle user

#
# Set the ASM env to be able to use crsctl commands
#
ORACLE_SID=`ps -ef | grep pmon | grep asm | awk '{print $NF}' | sed s'/asm_pmon_//' | egrep "^[+]"`

export ORAENV_ASK=NO
. oraenv > /dev/null 2>&1

#
# List of the nodes of the cluster
#
NODES=`olsnodes | awk '{if (NR<2){txt=$0} else{txt=txt","$0}} END {print txt}'`

#
# Show the Exadata model if possible (if this cluster is an Exadata)
#
if [ -f ${DBMACHINE} ]
then
	cat << !

		Cluster is a `grep -i MACHINETYPES ${DBMACHINE} | sed -e s':</*MACHINETYPES>::g' -e s'/^ *//' -e s'/ *$//'`

!
fi

crsctl stat res -p -w "TYPE = ora.database.type" >  $TMP
crsctl stat res -v -w "TYPE = ora.database.type" >> $TMP
	awk  -v NODES="$NODES" 'BEGIN\
        {	      FS = "="				;
		      split(NODES, nodes, ",")		;	# Make a table with the nodes of the cluster
		# some colors
	     COLOR_BEGIN =       "\033[1;"              ;
	       COLOR_END =       "\033[m"      		;
		     RED =       "31m"         		;
		   GREEN =       "32m"         		;
		  YELLOW =       "33m"         		;
		    BLUE =       "34m"       		;
		   WHITE =       "37m"         		;

	 	 UNKNOWN = "-"				;	# Something to print when the status is unknown
   	}	

	#
	# A function to center the outputs with colors
	#
        function center( str, n, color)
        {       right = int((n - length(str)) / 2)
                left  = n - length(str) - right
                return sprintf(COLOR_BEGIN color "%" left "s%s%" right "s" COLOR_END "|", "", str, "" )
        }

	#
	# A function that just print a "---" white line
	#
	function print_a_line()
	{
		printf("%s", COLOR_BEGIN WHITE)									;
		for (k=1; k<=12+(20*i); k++) {printf("%s", "-");}						;
		printf("%s", COLOR_END"\n")									;
	}
	     {
		# Fill 2 tables with the OH and the version from "crsctl stat res -p -w "TYPE = ora.database.type""
		if ($1 ~ /^NAME/)
               {
			sub("^ora.", "", $2)     								;
			sub(".db$", "", $2)      								;
			DB=$2                   								;
							
			getline; getline									;
			if ($1 == "ACL")		# crsctl stat res -p output
			{
				if (DB in version == 0)
				{
					while (getline)
					{
						if ($1 == "ORACLE_HOME")
						{	OH=$2							;
							match($2, /1[0-9]\.[0-9]\.[0-9]\.[0-9]/)		;
							VERSION=substr($2,RSTART,RLENGTH)			;
						}
						if ($0 ~ /^$/)
						{	version[DB]	= VERSION				;
							oh[DB]		= OH					;
							break							;
						}
					}
				}
			}
			if ($1 == "LAST_SERVER")	# crsctl stat res -v output
			{	    NB = 0	;	# Number of instance as CARDINALITY_ID is sometimes irrelevant
				SERVER = $2	;
				while (getline)
				{
					if ($1 == "LAST_SERVER")	{	SERVER = $2     		;}
					if ($1 == "STATE_DETAILS")	{	NB++				;	# Number of instances we came through
										sub("STATE_DETAILS=", "", $0)	;
										status[DB,SERVER] = $0		; }
					if ($1 == "INSTANCE_COUNT")     {	if (NB == $2) { break 		;}}
				}
			}
		}	# End of if ($1 ~ /^NAME/)
	     }
	    END {	# Print a header
			printf("%s", center("DB"	, 12, WHITE))						;
			printf("%s", center("Version"	, 10, WHITE))						;
			n=asort(nodes)										;        # sort array nodes
			for (i = 1; i <= n; i++) {
					printf("%s", center(nodes[i], 20, WHITE))				;
			}
			printf("\n")										;
			
			# a "---" line under the header
			print_a_line()										;

			m=asorti(version, version_sorted)							;
			for (j = 1; j <= m; j++)
			{
				printf("%s", center(version_sorted[j]		, 12, WHITE))			;
				printf("%s", center(version[version_sorted[j]]	, 10, WHITE))			;
				for (i = 1; i <= n; i++) {
					dbstatus = status[version_sorted[j],nodes[i]]				;

					#
					# Print the status here, all that are not listed in that if ladder will appear in RED
					#
					if (dbstatus == "") 			{printf("%s", center(UNKNOWN , 20, BLUE		))	;}	else
					if (dbstatus == "Open") 		{printf("%s", center(dbstatus, 20, GREEN	))	;}	else
					if (dbstatus == "Open,Readonly")	{printf("%s", center(dbstatus, 20, WHITE	))	;}	else
					if (dbstatus == "Readonly")		{printf("%s", center(dbstatus, 20, YELLOW	))	;}	else
					if (dbstatus == "Instance Shutdown")	{printf("%s", center(dbstatus, 20, YELLOW	))	;}	else
										{printf("%s", center(dbstatus, 20, RED		))	;}
				}
				printf("\n")									;
			}

			# a "---" line as a footer
			print_a_line()										;
		}' $TMP	

if [ -f ${TMP} ]
then
	rm -f ${TMP}
fi

#*********************************************************************************************************
#				E N D     O F      S O U R C E
#*********************************************************************************************************

