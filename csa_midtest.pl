#!/usr/bin/perl -w
use Cwd;
use Fcntl;
my $fqdn;
my $midware;
my $all_url;
my $env_url;
my $file_env;
my @url_name=();
my $jobmanager;
my %geturl=();
my $bigjob_script="https://raw.github.com/saga-project/BigJob/master/examples/example_local_single.py";
my $result_svn="https://svn.cct.lsu.edu/repos/saga_siva/test_results/";

 $fqdn=shift(@ARGV);
 $midware=shift(@ARGV);
 #$env_url=shift(@ARGV);
 $all_url=shift(@ARGV);
 $time=shift(@ARGV);
 $hostname=shift(@ARGV);

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
  chdir ("csa");
 my $csa_home=cwd();

#Remove the previous result directories
# if(-d "$csa_home/results_*")
# {
# print "Inside if";
 system("rm -rf $csa_home/results_*");
# }
 
 mkdir ("$csa_home/results_$time");
 my $results_home=("$csa_home/results_$time");
 chdir ("$csa_home/test_scripts");
 my $test_home=cwd();
 


#Get the url if it is globus or condor
 my $url=0;
 @url=();
 my $found="false";
 @url=split(/,/,$all_url);


 print "\n\n+------------------------ Submitting jobs - $hostname --------------------------+\n\n";
 foreach my $mw(@middleware)
 {


#X.509 Certificates
  if ($mw eq "gram")
  {
  print "\n#--- Enter the proxy credentials for X.509 certificate renewal ---#\n";
  system("myproxy-logon -q");
  }
 
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
   
if($mw eq "bigjob")
  {
   system("wget $bigjob_script > /dev/null 2>&1");

   system("python example_local_single.py > $results_home/result_$mw-$jm 2>&1");
  }
else {
   #Create the job script
   sysopen (JOB, "test_$mw-$jm.py", O_RDWR|O_EXCL|O_CREAT, 0755) or die "File already exists\n";
   
   printf JOB "import saga,os,time\n"; 
   printf JOB "home = os.getcwd()\n";
   printf JOB "def has_finished(state)\:\n";
   printf JOB " state \= state\.lower()\n";
   printf JOB " if state\=\=\"done\" or state\=\=\"failed\" or state\=\=\"canceled\"\:\n";
   printf JOB "     return True\n";
   printf JOB " else\:\n";
   printf JOB "     return False\n";


   printf JOB "def wait_for_all_jobs(jobs\, job_start_times\, job_states\, poll_intervall\=5)\:\n";
   printf JOB " while 1\:\n";
   printf JOB "     finish_counter\=0\n";
   printf JOB "     result_map \= {}\n";
   printf JOB "     number_of_jobs \= len(jobs)\n";
   printf JOB "     for i in range(0\, number_of_jobs)\:\n";
   printf JOB "         old_state \= str(job_states[jobs[i]])\n";
   printf JOB "         state \= str(jobs[i]\.get_state())\n";
   printf JOB "         if result_map\.has_key(state)\=\=False\:\n";
   printf JOB "             result_map[state]=1\n";
   printf JOB "         else\:\n";
   printf JOB "             result_map[state] \= result_map[state]\+1\n";
   printf JOB "         print \" Job state \- \" \+ str( state )\n";
   printf JOB "         if old_state \!\= state\:\n";
   printf JOB "             print \"Job changed from\: \" \+ old_state \+ \" to \" \+ state\n";
   printf JOB "         if old_state \!\= state and has_finished(state)\=\=True\:\n";
   printf JOB "             print \"Job runtime\: \" \+ str(time\.time()\-job_start_times[jobs[i]]) \+ \" s\.\"\n";
   printf JOB "         if has_finished(state)\=\=True\:\n";
   printf JOB "             finish_counter \= finish_counter \+ 1\n";
   printf JOB "         job_states[jobs[i]]\=state\n\n";

   printf JOB "     if finish_counter \=\= number_of_jobs\:\n";
   printf JOB "         break\n";
   printf JOB "     time\.sleep(10)\n\n";

   printf JOB "jobs \= []\n";
   printf JOB "job_start_times = {}\n";
   printf JOB "job_states = {}\n";
   printf JOB "try:\n";
   printf JOB "   jd = saga.job.description()\n";
   printf JOB "   jd\.set_attribute(\"Executable\"\,\"/bin/echo\")\n";
   printf JOB "   jd\.set_vector_attribute(\"Arguments\"\, [\"Hello\, World!\"])\n";
   printf JOB "   jd\.output=(\"$results_home\/out_$mw-$jm\")\n";
 
 if ($jm eq 'nourl' && $mw eq 'fork')
  {
  printf JOB "   js = saga.job.service(\"$mw://localhost\")\n";
  }
 elsif($jm eq 'nourl')
  {
  printf JOB "   js = saga.job.service(\"$mw://$fqdn\")\n";
  }
  else
  {
  printf JOB "   js = saga.job.service(\"$mw://$geturl{$mw}{$jm}\")\n";  
  }



printf JOB "   job = js\.create_job(jd)\n"; 
printf JOB "   job\.run()\n\n";
#printf JOB "   job\.wait(-1)\n\n";
printf JOB "   jobs\.append(job)\n";
printf JOB "   job_start_times[job]\=time\.time()\n";
printf JOB "   job_states[job] \= job\.get_state()\n";
printf JOB "except saga\.exception\, e:\n\n";
printf JOB "   print \"ERROR: \"\n";
printf JOB "   for err in e\.get_all_messages():\n";
printf JOB "     print err\n\n";
printf JOB "wait_for_all_jobs(jobs\, job_start_times\,job_states\, 5)\n";

system("nohup python \$HOME/csa/test_scripts/test_$mw-$jm.py > $results_home/result_$mw-$jm 2>&1 &");
}
sleep(5);
my $flag=0;
open (RE, "$results_home/result_$mw-$jm") or die "Cannot open result file\n";
my @result = <RE>;
close  (RE);
chomp  (@result);
foreach my $result ( @result )
 {
  #if ($result =~ /^\s*(ERROR|error)(:\s*)*$/io)
  if (($result =~ m/error/) or ($result =~ m/Error/) or ($result =~ /^\s*(ERROR|error)(:\s*)*$/io))
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

 while(-z "$results_home\/out_$mw-$jm")
 {
 sleep(5);
 }

}

}


}
print "\n\n+-----------------------------------------------------------------------------+\n\n";

#Add the results back to svn
  system("svn import $results_home $result_svn\/results_$time\/$hostname\/ -m \"Added results\" -q")
