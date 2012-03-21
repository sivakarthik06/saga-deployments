#!/usr/bin/perl -w

use Fcntl;
my $fqdn;
my $midware;
my $all_url;
my $env_url;
my $file_env;
my @url_name=();
my $jobmanager;
my %geturl=();

 $fqdn=shift(@ARGV);
 $midware=shift(@ARGV);
 #$env_url=shift(@ARGV);
 $all_url=shift(@ARGV);


#Get all the middlewares in an array to compare and submit jobs
my @middleware=split(/,/,$midware);


#Get all url's in an array
 my @url=split(/,/,$all_url);
 foreach my $h (@url)
  {
  my @url_both=split(/=/,$h);

 #Get the name of the job manager
 if($url_both[1])
 { 
 if ($url_both[1] =~ (/^\s*([\w+=.:]+)\/([\w+-]+)*$/))
   {
   $jobmanager = $2;
   }
  $geturl{$url_both[0]}{$jobmanager}=$url_both[1];
  }
 }

#Change to test directory
 chdir ("csa");;
 chdir ("test_scripts");

=head
#Get the README file from the SAGA website
 system("wget -q $env_url");

#Get the name of the file 
 if ($env_url =~ (/^\s*(([\w+.:\/-]+)(README([\w+.-]+)))*$/io))
 {
 $file_env=$3;
 }


#Export all the variables
 if (-e "env.sh")
 {
 system ("rm env.sh");
 }
 sysopen (SC, "env.sh", O_RDWR|O_EXCL|O_CREAT, 0755) or die "File already exists\n";
 open (TF, "<$file_env") or die "File already exists\n";
 my @tf = <TF>;
 close  (TF);
 chomp  (@tf);
 foreach my $tf ( @tf )
   {	
	if ( $tf =~ /^\s*(?:#.*)?$/io )
    	{
      	# skip comment lines and empty lines
    	}
        elsif ( $tf =~ /^\s*export\s+(\S+?)=(.+)?\s*$/io )
 	{
        print "$1 \n $2 \n";
	#print "Enter yes or no";
        #my $f=<>;
        #	if ($f eq "y")
        #	{
#   		$ENV{$1} = $2;
        #	}
 	}
=cut
=head	
	elsif ($tf =~ (/^\s*?((export)\s+)/io))
	{
	printf SC "$tf\n";
	}


   }
 close(TF);
 close(SC);
 #system("source env.sh");
=cut
#Get the url if it is globus or condor
 my $url=0;
 @url=();
 my $found="false";
 @url=split(/,/,$all_url);

 print "\n\n+----------------------------- Submitting jobs -------------------------------+\n\n";
 foreach my $mw(@middleware)
 {
  if ((scalar keys %{$geturl{$mw}}) eq 0)
  {
  $geturl{$mw}{'nourl'}={};
  }
 my @jm=keys %{$geturl{$mw}};
  foreach my $jm (@jm)
  {
  	if (-e "test_$mw-$jm.py")
        {
        my $a=system("rm test_$mw-$jm.py");
        }
   {
   #Create the job script
   sysopen (JOB, "test_$mw-$jm.py", O_RDWR|O_EXCL|O_CREAT, 0755) or die "File already exists\n";
   
   printf JOB "import saga,os\n"; 
   printf JOB "print \"Inside\"\n";
   printf JOB "home = os.getcwd()\n";
   printf JOB "try:\n";
   printf JOB "   jd = saga.job.description()\n";
   printf JOB "   jd\.set_attribute(\"Executable\"\,\"/bin/echo\")\n";
   printf JOB "   jd\.set_vector_attribute(\"Arguments\"\, [\"Hello\, World!\"])\n";
   printf JOB "   jd\.output=(home\+\"/out_$mw-$jm\")\n";
   printf JOB "   jd\.error=(home\+\"/err_$mw-$jm\")\n\n";
   }
 if ($jm eq 'nourl')
  {
  printf JOB "   js = saga.job.service(\"$mw://$fqdn\")\n";
  }
  else
  {
  printf JOB "   js = saga.job.service(\"$mw://$geturl{$mw}{$jm}\")\n";  
  }



printf JOB "   job = js\.create_job(jd)\n"; 
printf JOB "   job\.run()\n\n";
printf JOB "except saga\.exception\, e:\n";
printf JOB "   print \"ERROR: \"\n";
printf JOB "   for err in e\.get_all_messages():\n";
printf JOB "     print err\n";
close (JOB);


system("python \$HOME/csa/test_scripts/test_$mw-$jm.py >> result_$mw-$jm");

my $flag=0;
open (RE, "result_$mw-$jm") or die "Result file already exists\n";
my @result = <RE>;
close  (RE);
chomp  (@result);
foreach my $result ( @result )
 {
  if ($result =~ /^\s*(ERROR|error)(:\s*)*$/io)
  {
  $flag=1;
  }
 }


if($flag)
{
print "$mw - $jm ------> Failed \n";
}
else
{
print "$mw - $jm ------> Success! \n";
}
}
}
print "\n\n+-----------------------------------------------------------------------------+\n\n";

