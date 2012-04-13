#!/usr/bin/perl -w
use Fcntl;
use strict;
use Cwd;

my $env_url  = shift(@ARGV);
my $modules  = shift(@ARGV);
my $file_env = 0;

#Change to test directory
 chdir ("csa");
 if (-d "test_scripts")
 {
   system ("rm -r -f test_scripts");
 }
 system ("mkdir test_scripts");
 chdir ("test_scripts");
 my $home=getcwd();

#Get the specific modules into the list
 my @modules = split(/,/,$modules);

#Get the README file from the SAGA website
 system ("wget --no-check-certificate -q $env_url");

#Get the name of the file
 if ($env_url =~ (/^\s*(([\w+.:\/-]+)(README([\w+.-]+)))*$/io))
 {
   $file_env = $3;
 }

#Export all the variables
 if (-e "env.sh")
 {
   system ("rm env.sh");
 }

#Find the type of shell
 my $sh = `echo \$SHELL`;

 sysopen (SC, 'env.sh', O_RDWR|O_EXCL|O_CREAT, 0755) or die "Env files exists already\n";
 open (TF, "<$file_env") or die "Cannot open file\n";
 my @tf = <TF>;
 close  (TF);
 chomp  (@tf);

 foreach my $mod (@modules)
 {
   print SC "$mod\n";
 }

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

 close (TF);
 close (SC);

