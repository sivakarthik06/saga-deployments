#!/usr/bin/perl -w
use Fcntl;
=head
#my $a=`which qsub`;
#$_=$a;
#my $b=s/bin.*//ig;
#print $_;
my %h=();
$h{'i'}{'midware'}="hello";
$h{'i'}{'url'}="hi";
$h{'j'}{'midware'}="hello";
$h{'j'}{'url'}="hi";
my @t= keys %h;
for my $i (@t)
{
print "$i \n";
}
my $url=0;
my $tf="lonestar    gram,torque                            https://svn.cct.lsu.edu/repos/saga-projects/deployment/tg-csa/doc/README.saga-1.6.gcc-4.1.2.lonestar                           gram=gridftp1.ls4.tacc.utexas.edu/jobmanager-sge";
if( $tf =~ (/^\s*(\w+)\s+(\w+,*\w+)\s+(((\w+):\/\/[\w+.\/-]+)|([\w]+))\s+(((\w+)=[\w+.\/-]+)|([\w]+))*$/io) )
{
print "Match found\n";
print $1."\n";
print $2."\n";
print $3."\n";
$url=$3;
print $7."\n";
}
else
{
print "Match not found\n";
}
print "url is $url \n";
if ($url =~ (/^\s*(([\w+.:\/-]+)\.([\w]+))*$/io))
{
print "$2 \n";
print "$3 \n";
}

my $h="no";
my @j=split(/=/,$h);
foreach my $j (@j)
{
print "j is $j\n";
}
my $fname = "README.saga-1.6.gcc-4.1.2.lonestar"; 
sysopen (JOB, "$fname", O_RDWR|O_EXCL|O_CREAT, 0755) or die "File already exists\n"; 
@tf = <TF>;
close  (TF);
chomp  (@tf);
foreach my $tf ( @tf )
{
if ($tf=(/^\s*export(\w+.:\/-_)*$/io))
{
print $tf;
}
=cut  
my $flag=0;
open (RE, "result") or die "Result file already exists\n";
my @result = <RE>;
close  (RE);
chomp  (@result);
foreach my $result ( @result )
 {
  print "Result is $result \n";
  if ($result =~ /^\s*(ERROR|error)(:\s*)*$/io)
  {
  print "Inside flag \n";
  $flag=1;
  }
 }

if($flag)
{
print " ------> Failed \n";
}
else
{
print " ------> Success! \n";
}

#close(JOB);
