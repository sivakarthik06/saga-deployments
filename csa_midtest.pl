#!/usr/bin/perl -w
use Fcntl;
use strict;
my $fqdn;
my $midware;
my $all_url;
my $env_url;
my $file_env;

 $fqdn=shift(@ARGV);
 $midware=shift(@ARGV);
 $env_url=shift(@ARGV);
 $all_url=shift(@ARGV);

#Get all the middlewares in an array to compare and submit jobs
my @middleware=split(/,/,$midware);

chdir ("csa");
if (-d "test_scripts")
{
system ("rm -rf test_scripts");
}

system ("mkdir test_scripts");

chdir ("test_scripts");

#Get the Environmental variables frm the SAGA website
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
	elsif ($tf =~ (/^\s*?((export)\s+)/io))
	{
	printf SC "$tf\n";
	}
   }
close(TF);
close(SC);
#system("source env.sh");

print "\n\n+----------------------------- Submitting jobs -------------------------------+\n\n";
foreach my $mw(@middleware)
{
if (-e "test_$mw.py")
{
my $a=system("rm test_$mw.py");
} 

{
#Create the job script
sysopen (JOB, "test_$mw.py", O_RDWR|O_EXCL|O_CREAT, 0755) or die "File already exists\n";
printf JOB "import saga,os\n"; 
printf JOB "home = os.getcwd()\n";
printf JOB "try:\n";
printf JOB "   jd = saga.job.description()\n";
printf JOB "   jd\.set_attribute(\"Executable\"\,\"/bin/echo\")\n";
printf JOB "   jd\.set_vector_attribute(\"Arguments\"\, [\"Hello\, World!\"])\n";
printf JOB "   jd\.output=(home\+\"/out_$mw\")\n";
printf JOB "   jd\.error=(home\+\"/err_$mw\")\n\n";
}
#Get the url if it is globus or condor
my $url=0;
my $found="false";
my @url=split(/,/,$all_url);
#if(!($all_url eq "no"))
#{
 
foreach my $m (@url)
 {
my @urldiv=split(/=/,$m);
 if ($urldiv[0] eq $mw)
  {
  printf JOB "   js = saga.job.service(\"$mw://$urldiv[1]\")\n";  
  $found="true";
  }
 }
 if($found eq "false")
  {
  printf JOB "   js = saga.job.service(\"$mw://$fqdn\")\n";
  }

# }
#}
#else
#{
# printf JOB "   js = saga.job.service(\"$mw://$fqdn\")\n";
#}

if (-e "test_script.py")
{
my $a=system("rm test_script.py");
}
=head
#Create the job script
sysopen (JOB, 'test_script.py', O_RDWR|O_EXCL|O_CREAT, 0755) or die "File already exists\n";
printf JOB "import saga\n"; 
printf JOB "try:\n"; 
printf JOB "   jd = saga.job.description()\n"; 
printf JOB "   jd\.set_attribute(\"Executable\"\,\"/bin/echo\")\n"; 
printf JOB "   jd\.set_vector_attribute(\"Arguments\"\, [\"Hello\, World!\"])\n"; 
printf JOB "   jd\.output=\"$mw_out\"\n";
printf JOB "   jd\.error=\"stderr\"\n\n"; 
if ($url eq "no" || $url eq "0")
{
printf JOB "   js = saga.job.service(\"$midware://$fqdn\")\n";
}
else
{
printf JOB "   js = saga.job.service(\"$midware://$url\")\n";
}
#printf JOB "   js = saga.job.service(\"midware)
=cut

printf JOB "   job = js\.create_job(jd)\n"; 
printf JOB "   job\.run()\n\n";
printf JOB "except saga\.exception\, e:\n";
printf JOB "   print \"ERROR: \"\n";
printf JOB "   for err in e\.get_all_messages():\n";
printf JOB "     print err\n";
close (JOB);

system("python \$HOME/csa/test_scripts/test_$mw.py >> result_$mw");
my $flag=0;
open (RE, "result_$mw") or die "Result file already exists\n";
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
print "$mw ------> Failed \n";
}
else
{
print "$mw ------> Success! \n";
}
}
print "\n\n+-----------------------------------------------------------------------------+\n\n";

