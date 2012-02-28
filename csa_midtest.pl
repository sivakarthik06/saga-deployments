#!/usr/bin/perl -w
use Fcntl;

my $fqdn;
my $midware;
my $url;

 $fqdn=shift(@ARGV);
 $midware=shift(@ARGV);
 $url=shift(@ARGV);


if (-e "test_script.py")
{
my $a=system("rm test_script.py");
}

#Create the job script
sysopen (JOB, 'test_script.py', O_RDWR|O_EXCL|O_CREAT, 0755) or die "File already exists\n";
printf JOB "import saga\n"; 
printf JOB "try:\n"; 
printf JOB "   jd = saga.job.description()\n"; 
printf JOB "   jd\.set_attribute(\"Executable\"\,\"/bin/echo\")\n"; 
printf JOB "   jd\.set_vector_attribute(\"Arguments\"\, [\"Hello\, World!\"])\n"; 
printf JOB "   jd\.output=\"stdout\"\n";
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
printf JOB "   job = js\.create_job(jd)\n"; 
printf JOB "   job\.run()\n\n";
printf JOB "except saga\.exception\, e:\n";
printf JOB "   print \"ERROR: \"\n";
printf JOB "   for err in e\.get_all_messages():\n";
printf JOB "     print err\n";
close (JOB);

my $success=system("python test_script.py");

if(!$success)
{
print "Job submitted successfully \n";
}
else
{
print "Error: Job submission unsuccessfull \n";
}
