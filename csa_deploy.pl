#!/usr/bin/perl -w

BEGIN {
  use strict;
  use Data::Dumper;

  sub help (;$);
}


my $CSA_HOSTS   = "./csa_hosts";
my $CSA_PACK    = "./csa_packages";
my $CSA_TEST    = "./csa_test";
my $ENV         = `which env`;
my $svn         = "https://svn.cct.lsu.edu/repos/saga_siva/csa_testing/";
my %csa_hosts   = ();
my %csa_packs   = ();
my %test_hosts  = ();
my @modules     = ();
my @hosts       = ();
my @middleware  = ();
my $def_version = "";
my $version     = "";
my $do_exe      = 0;
my $do_list     = 0;
my $do_check    = 0;
my $do_deploy   = 0;
my $be_strict   = 0;
my $do_test     = 0;
my $do_force    = 0;
my $force       = "";
my $fake        = 0;
my $show        = 0;
my $do_remove   = 0;
my $svnuser     = `id -un`;
my $svnpass     = "";

chomp ($svnuser);
chomp ($ENV);

if ( ! scalar (@ARGV) )
{
  help (-1);
}

while ( my $arg = shift )
{
  if ( $arg =~ /^(-l|--list)$/io )
  {
    $do_list = 1;
  }
  elsif ( $arg =~ /^(-c|--check)$/io )
  {
    $do_check = 1;
  }
  elsif ( $arg =~ /^(-v|--version)$/io )
  {
    $version = shift || "";
  }
  elsif ( $arg =~ /^(-t|--target|--targets|--targethosts)$/io )
  {
    my $tmp = shift || "all";
    @hosts = split (/,/, $tmp);
  }
  elsif ( $arg =~ /^(-m|--module|--modules)$/io )
  {
    my $tmp = shift || "all";
    @modules = split (/,/, $tmp);
  }
  elsif ( $arg =~ /^(-u|--user)$/io )
  {
    $svnuser = shift || ""; 
  }
  elsif ( $arg =~ /^(-p|--pass)$/io )
  {
    $svnpass = shift || "";
  }
  elsif ( $arg =~ /^(-n|--nothing|--noop|--no)$/io )
  {
    $fake = 1;
  }
  elsif ( $arg =~ /^(-s|--show)$/io )
  {
    $show = 1;
  }
  elsif ( $arg =~ /^(-e|--error|--exit)$/io )
  {
    $be_strict = 1;
  }
  elsif ( $arg =~ /^(-f|--force)$/io )
  {
    $do_force = 1;
    $force    = "CSA_FORCE=true";
  }
  elsif ( $arg =~ /^(-r|--remove)$/io )
  {
    $do_remove = 1;
  }
  elsif ( $arg =~ /^(-d|--deploy)$/io )
  {
    $do_deploy = 1;
  }
  elsif ( $arg =~ /^(-x|--execute)$/io )
  {
    $do_exe = 1;
  }
  elsif ( $arg =~ /^(-h|--help)$/io )
  {
    help (0);
  }
  elsif ( $arg =~ /^(-j|--job)$/io )
  {
   $do_test = 1;
   my $tmp = shift || "all";
   @middleware = split (/,/, $tmp);
  }
  elsif ( $arg =~ /^-/io )
  {
    warn "WARNING: cannot parse command line flag '$arg'\n";
  }
  else
  {
    help (-1);
  }
}

if ( ! scalar (@hosts) )
{
  $hosts[0] = 'all';
}

if ( ! scalar (@modules) )
{
  $modules[0] = 'all';
}


my $SVNCI = "svn --no-auth-cache";
if ( $svnuser ) { $SVNCI .= " --username '$svnuser'"; }
if ( $svnpass ) { $SVNCI .= " --password '$svnpass'"; }
$SVNCI .= " ci";

# read and parse csa packages file
{
  my $tmp = ();

  open   (TMP, "<$CSA_PACK") || die "ERROR  : cannot open '$CSA_PACK': $!\n";
  @tmp = <TMP>;
  close  (TMP);
  chomp  (@tmp);

  my $tmp_version = "";

  LINE_P:
  foreach my $tmp ( @tmp )
  {
    if ( $tmp =~ /^\s*(?:#.*)?$/io )
    {
      # skip comment lines and empty lines
    }
    elsif ( $tmp =~ /^\s*default\s*:\s*(\S+)\s*$/ )
    {
      $def_version = $1;
      next LINE_P;
    }
    elsif ( $tmp =~ /^\s*version\s*:\s*(\S+)\s*$/ )
    {
      $tmp_version = $1;
      $csa_packs {$tmp_version} = ();
      next LINE_P;
    }
    elsif ( $tmp =~ /^\s*(\S+)\s+(\S+)(?:\s+(\S.*?))?\s*$/io )
    {
      my $tmp_mod  = $1;
      my $tmp_src  = $2;
      my $tmp_tgt  = $3 || "*";
      #print  $tmp_tgt . "\n";
      
      my @tmp_tgts = split (/[\s,]+/, $tmp_tgt);
      
       #foreach my $val (@tmp_tgts){
       # print $val."\n";
       # }
      push ( @{$csa_packs{$tmp_version}{'modules'}}, {'name' => $tmp_mod,
                                                      'src'  => $tmp_src, 
                                                      'tgt' => \@tmp_tgts});
    }
    else
    {
      die "WARNING: Cannot parse csa package line '$tmp'\n";
    }
  }
}


# fall back to default version if needed
{
  if ( $version eq "" )
  {
    $version = $def_version;
    print "no version specified - using default version: $version\n";
  }

  if ( ! exists $csa_packs{$version} )
  {
    print " -- error: undefined version '$version'\n";
    exit -1;
  }
}

# read and parse csa host file
{
  my $tmp = ();

  open   (TMP, "<$CSA_HOSTS") || die "ERROR  : cannot open '$CSA_HOSTS': $!\n";
  @tmp = <TMP>;
  close  (TMP);
  chomp  (@tmp);

  foreach my $tmp ( @tmp )
  {
  
    if ( $tmp =~ /^\s*(?:#.*)?$/io )
    {
      # skip comment lines and empty lines
    }
    elsif ( $tmp =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+((?:ssh|gsissh)\s*?.*?)\s*$/io )
    {
      my $host   = $1;
      my $fqhn   = $2;
      my $path   = $3;
      my $access = $4;

      if ( exists ( $csa_hosts{$host} ) )
      {
        warn "WARNING: duplicated csa host '$host'\n"
      }
      $csa_hosts {$1}{'fqhn'}   = $fqhn;
      $csa_hosts {$1}{'path'}   = $path;
      $csa_hosts {$1}{'access'} = $access;
}
    else
    {
      warn "WARNING: Cannot parse csa host line '$tmp'\n";
    }
  }
}


if ( grep (/all/, @modules) )
{
  @modules = grep (!/all/, @modules);
  foreach my $entry ( @{$csa_packs{$version}{'modules'}} )
  {
    push (@modules, $entry->{'name'});
  }
}

# modules need to be re-ordered, as we assume that the order given in the
# csa_packages file is significant (i.e. resolves dependenncies).
# FWIW, this procedure also weeds out duplicates.
#
# TODO: for each module, we should also include all modules listed before 
# that one, to actually satisfy not specified dependencies...
{ 
  my  @tmp = @modules;
  @modules = ();

  foreach my $entry ( @{$csa_packs{$version}{'modules'}} )
  {
    my $name = $entry->{'name'};
    if ( grep (/^$name$/, @tmp) )
    {
      push (@modules, $entry);
    }
  }
}


if ( grep (/all/, @hosts) )
{
  @hosts = grep (/all/, @hosts);
  @hosts = sort keys ( %csa_hosts );
}

if ( ! scalar (@hosts) )
{
  if ( $do_check || $do_deploy || $do_exe || $do_remove )
  {
    die "no targets given\n";
  }
}

my $modstring = "";
foreach my $entry ( @modules )
{
  $modstring .= "$entry->{name} ";
}

print <<EOT;
+-------------------------------------------------------------------
|
| targets  : @hosts
| modules  : $modstring
| version  : $version
|
| exec     : $do_exe
| remove   : $do_remove
| deploy   : $do_deploy
| check    : $do_check
| test job : $do_test
|
| force    : $do_force
| strict   : $be_strict
|
+-------------------------------------------------------------------
EOT


# list mode simply lists the known hosts
if ( $do_list )
{
  print "\n";
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  printf "| %-15s | %-40s | %-35s |\n", "host", "fqhn", "path";
  print "+-----------------+------------------------------------------+-------------------------------------+\n";

  foreach my $host ( sort keys (%csa_hosts) )
  {
    if ( ! exists $csa_hosts{$host} )
    {
      warn "WARNING: Do not know how to handle host '$host'\n";
    }
    else
    {
      my $fqhn = $csa_hosts{$host}{'fqhn'};
      my $path = $csa_hosts{$host}{'path'};
    
      printf "| %-15s | %-40s | %-35s |\n", $host, $fqhn, $path;
    }
  }
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  print "\n";
}


# for each csa host, execute some maintainance op
if ( $do_exe )
{
  print "\n";
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  printf "| %-15s | %-40s | %-35s |\n", "host", "fqhn", "path";

  foreach my $host ( @hosts )
  {
    if ( ! exists $csa_hosts{$host} )
    {
      print " -- warning: unknown host '$host'\n";
    }
    else
    {
      my $fqhn   = $csa_hosts{$host}{'fqhn'};
      my $path   = $csa_hosts{$host}{'path'};
      my $access = $csa_hosts{$host}{'access'};
      my $CPP    = "gcc-`$path/csa/cpp_version`";

    # my $exe    = "rm -rf $path/csa";
    # my $exe    = "chmod -R a+rX $path/";
    # my $exe    = "rm -v  $path/saga/$version/$CPP/share/saga/saga_adaptor_ssh_job.ini";
    # my $exe    = "rm -rf $path/saga/$version/$CPP/lib/python*/site-packages/bigjob* " .
    #              "       $path/saga/$version/$CPP/lib/python*/site-packages/saga/bigjob*";
    # my $exe    = "rm -rv $path/README.saga-$version.$CPP.$host" .
    #              "       $path/csa/doc/README.saga-$version.$CPP.$host" .
    #              "       $path/saga/$version/$CPP/share/saga/config/python.m4" .
    #              "       $path/saga/$version/$CPP/lib/python*";
    # my $exe    = "eval `grep \"  export\" $path/README.saga-1.6.*.$host` ; " .
    #              "python -c \"import saga ; print saga ; import bigjob ; print bigjob\"";
    # my $exe    = "rm -rv $path/src/saga-client-bigjob-*" .
    #              "       $path/saga/$version/$CPP/lib/python*/site-packages/* " .
    #              "       $path/external/python/2.7.1/$CPP/lib/python*/site-packages/*" .
    #              "       $path/saga/$version/$CPP/share/saga/config/python.m4" ;
      my $exe    = "rm -rv $path/csa/{doc,mod,test}/ ; " .
                   "cd     $path/     ; test -d csa || svn co https://svn.cct.lsu.edu/repos/saga-projects/deployment/tg-csa csa ; " .
                   "cd     $path/csa/ ; svn up";

      print "+-----------------+------------------------------------------+-------------------------------------+\n";
      printf "| %-15s | %-40s | %-35s |\n", $host, $fqhn, $path;
      print "+-----------------+------------------------------------------+-------------------------------------+\n";

      if ( $show || $fake )
      {
        print " -- $access $fqhn '$exe'\n";
      }
      
      unless ( $fake )
      {
        my $cmd = "$access $fqhn '$exe'";

        if ( 0 != system ($cmd) )
        {
          print " -- error: cannot run $cmd\n";
          exit -1 if $be_strict;
        }
      }
    }
  }
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  print "\n";

}


if ( $do_remove )
{
  # ! check, so do the real deployment

  print "\n";
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  printf "| %-15s | %-40s | %-35s |\n", "host", "fqhn", "path";

  foreach my $host ( @hosts )
  {
    if ( ! exists $csa_hosts{$host} )
    {
      warn " -- warning: unknown host '$host'\n";
    }
    else
    {
      my $fqhn   = $csa_hosts{$host}{'fqhn'};
      my $path   = $csa_hosts{$host}{'path'};
      my $access = $csa_hosts{$host}{'access'};

      print "+-----------------+------------------------------------------+-------------------------------------+\n";
      printf "| %-15s | %-40s | %-35s |\n", $host, $fqhn, $path;
      print "+-----------------+------------------------------------------+-------------------------------------+\n";

      print " -- remove installation $version on $host\n";

      my $cmd = "$access $fqhn 'rm -rf $path/saga/$version/ $path/README.saga-$version.*.$host'";

      if ( $show || $fake )
      {
        print " -- $cmd\n";
      }

      unless ( $fake )
      {
        if ( 0 != system ($cmd) )
        {
          print " -- error: cannot remove csa installation\n";
          exit -1 if $be_strict;
        }
      }
    }
  }
}



if ( $do_deploy )
{
  # ! check, so do the real deployment

  print "\n";
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  printf "| %-15s | %-40s | %-35s |\n", "host", "fqhn", "path";

  foreach my $host ( @hosts )
  {
    if ( ! exists $csa_hosts{$host} )
    {
      warn " -- warning: unknown host '$host'\n";
    }
    else
    {
      my $fqhn   = $csa_hosts{$host}{'fqhn'};
      my $path   = $csa_hosts{$host}{'path'};
      my $access = $csa_hosts{$host}{'access'};

      print "+-----------------+------------------------------------------+-------------------------------------+\n";
      printf "| %-15s | %-40s | %-35s |\n", $host, $fqhn, $path;
      print "+-----------------+------------------------------------------+-------------------------------------+\n";

      
      foreach my $entry ( @modules )
      {
        my $mod_name = $entry->{'name'};
        my $mod_src  = $entry->{'src'};
        my @mod_tgts = @{$entry->{'tgt'}};

        print " -- build $mod_name ($version) (@mod_tgts)\n";

        if ( ! grep (/\!$host/, @mod_tgts)    &&
             ( grep (/\*/,      @mod_tgts) ||
               grep (/$host/,   @mod_tgts) )  )
        {
          my $cmd = "$access $fqhn 'mkdir -p $path ; " .
                                   "cd $path && test -d csa && (cd csa && svn up) || svn co $svn csa; ". 
                                   "$ENV CSA_HOST=$host                 " .
                                   "     CSA_LOCATION=$path             " .
                                   "     CSA_SAGA_VERSION=$version      " .
                                   "     CSA_SAGA_SRC=\"$mod_src\"      " .
                                   "     CSA_SAGA_TGT=$mod_name-$version" .
                                   "     $force                         " .
                                   "     make -C $path/csa/             " .
                                   "          --no-print-directory      " .
                                   "          -f make.saga.csa.mk       " .
                                   "          $mod_name               ' " ;
          if ( $show || $fake )
          {
            print " -- $cmd\n";
          }
          
          unless ( $fake )
          {
            if ( 0 != system ($cmd) )
            {
              print " -- error: cannot deploy $mod_name on $host\n";
              exit -1 if $be_strict;
            }
          }

          if ( $mod_name eq "documentation" )
          {
            my $cmd = "$access $fqhn ' cd $path/csa/                            && " .
                                     " svn add doc/README.saga-$version.*.$host && " .
                                     " svn add mod/module.saga-$version.*.$host && " .
                                     " $SVNCI -m \"automated update\"              " .
                                     "   doc/README.saga-$version.*.$host          " .
                                     "   mod/module.saga-$version.*.$host       '  " ;
            if ( $show || $fake )
            {
              print " -- $cmd\n";
            }
            
            unless ( $fake )
            {
              if ( 0 != system ($cmd) )
              {
                print " -- error: cannot commit documentation\n";
                exit -1 if $be_strict;
              }
            }
          }
          print "\n";
        }
        else
        {
          print "module $mod_name disabled on $host\n";
        }
      }
    }
  }
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  print "\n";
}



# for each csa host, check the csa installation itself (also check on deploy!)
if ( $do_check )
{
  # just check if we are able to deploy
  print "\n";
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  printf "| %-15s | %-40s | %-35s |\n", "host", "fqhn", "path";

  foreach my $host ( @hosts )
  {
    if ( ! exists $csa_hosts{$host} )
    {
      print " -- warning: unknown host '$host'\n";
    }
    else
    {
      my $fqhn   = $csa_hosts{$host}{'fqhn'};
      my $path   = $csa_hosts{$host}{'path'};
      my $access = $csa_hosts{$host}{'access'};

      print "+-----------------+------------------------------------------+-------------------------------------+\n";
      printf "| %-15s | %-40s | %-35s |\n", $host, $fqhn, $path;
      print "+-----------------+------------------------------------------+-------------------------------------+\n";

      {
        my $cmd = "$access $fqhn 'mkdir -p $path ; " .
                  "cd $path && test -d csa && (cd csa && svn up) || svn co $svn csa; ". 
                  "$ENV CSA_HOST=$host                 " .
                  "     CSA_LOCATION=$path             " .
                  "     CSA_SAGA_VERSION=$version      " .
                  "     CSA_SAGA_CHECK=yes             " .
                  "     make -C $path/csa/             " .
                  "          --no-print-directory      " .
                  "          -f make.saga.csa.mk       " .
                  "          all'                      " ;

        if ( $show || $fake )
        {
          print " -- $cmd\n";
        }
        
        unless ( $fake )
        {
          if ( 0 != system ($cmd) )
          {
            print " -- error: cannot run csa checks\n";
            exit -1 if $be_strict;
          }
        }
      }

      {
        my $cmd = "$access $fqhn ' cd $path/csa/                           && " .
                                 " svn add test/test.saga-$version.*.$host && " .
                                 " $SVNCI -m \"automated update\"             " .
                                 "    test/test.saga-$version.*.$host      '  " ;
        if ( $show || $fake )
        {
          print " -- $cmd\n";
        }
        
        unless ( $fake )
        {
          if ( 0 != system ($cmd) )
          {
            print " -- error: cannot commit csa checks\n";
            exit -1 if $be_strict;
          }
        }
      }
    }
  }
  print "+-----------------+------------------------------------------+-------------------------------------+\n";
  print "\n";
}

#Submit jobs on machines specified..

if ( $do_test )
{
  my @midware    =  ();      
  my $test_host  =  0;
  my $midware    =  0;
  my @temp_host  =  ();
  my @notfound   =  ();
  my %test_hosts =  ();
  my @temp       =  ();
  my @tmp        =  ();
  my $cmd        =  0;
  my $time       =  localtime(time);
  $time          =~ s/ /_/g;
  $time          =~ s/:/-/g;

  open (TF, "<$CSA_TEST") || die "ERROR  : cannot open '$CSA_TEST': $!\n";
  @tf = <TF>;
  close  (TF);
  chomp  (@tf);
  foreach my $tf ( @tf )
  {
    if ( $tf =~ /^\s*(?:#.*)?$/io )
    {
      # skip comment lines and empty lines
    }
    elsif ( $tf =~ (/^\s*(\w+)\s+([\w+,\/_=\s]+)*$/io ) )
    {
      if ( (grep {$_ eq $1} @hosts) && (exists $csa_hosts{$1}) )
      {
        $test_hosts {$1}{'modules'} = $2;   
      }
    }
    elsif ( $tf =~ (/^\s*(\w+)\s+([\w+,*]+)\s+(((\w+)[\w+.:,\/-]+)|([\w]+))\s*(((\w+)[\w+.,=\/:-]+)|([\w]+))*$/io) )
    {
      $test_host   = $1; 
      $midware     = $2;
      $env_url	   = $3;
      $url         = $7;

      if ( !defined($url) )
      {
        $url="no";
      }

      # Get all the middlewares in @midware array      
      my @tmp_midware=split (/,/, $midware);
      foreach my $m ( @tmp_midware )
      {
        if ( !grep {$_ eq $m} @midware )
        {      
          push ( @midware,$m );
        }
      } 
     
       # Check whether test host is present in the csa_hosts file    
      if ( (grep {$_ eq $test_host} @hosts) && (exists $csa_hosts{$test_host}) )
      {
        $test_hosts {$test_host}{'middware'}   = $midware;
        $test_hosts {$test_host}{'url'}        = $url;
        $test_hosts {$test_host}{'env_url'}    = $env_url;
      }
    }
    else
    {
      warn "WARNING: Cannot parse test host line '$tf'\n";
    }
  }
        
  @temp_host=keys %test_hosts;
  
  foreach my $host ( @hosts )
  {
    if ( ! exists $csa_hosts{$host} )
    {
      warn " -- warning: unknown host '$host'\n";
    }
    elsif ( !grep {$_ eq $host} @temp_host )
    {
      warn "WARNING: Host '$host' not added to the csa_test file\n";
    }
  }

  if ( ! grep (/all/, @middleware) )
  {
    foreach my $mid ( @middleware )
    {
      if ( !grep {$_ eq $mid} @midware )
      {
        warn "WARNING: unknown middleware '$mid' \n";
      }  
    }
  } 

  # Print all the available and unavailable middlewares respective to the hosts

  print "+-----------------+------------------------------------------+------------------------------------+\n";
  printf "| %-15s | %-40s | %-35s|\n", "Host", "Available", "Not Available";
  print "+-----------------+------------------------------------------+------------------------------------+\n";
  foreach my $h ( @temp_host )
  {
    @tmp=();
    @temp=();
    printf "| %-15s |",$h;
    my @temp_midware = split (/,/,$test_hosts{$h}{'middware'});
    
    if ( grep (/all/, @middleware) )
    {
      $" = ",";
      printf " %-40s |","@temp_midware";
      printf "%-35s |",""; 
    } 
    else
    {
      foreach my $m ( @middleware )
      {
        if ( grep (/$m/,@temp_midware) )
        {
          push ( @tmp, $m );
        }
        else
        {
          push ( @temp, $m );
        }
      }
      $" = ",";
      my $a=@tmp;
      
      if ( $a )
      {
        $test_hosts{$h}{'middware'}="@tmp";
      }
      else
      {  
        $test_hosts{$h}{'middware'}=();
      }
      printf " %-40s |","@tmp";
      printf "%-35s |","@temp"; 
    } 
    printf "\n";
    print "+-----------------+------------------------------------------+------------------------------------+\n";
  }
  my $url = "no";
  my $modules="";
  
  foreach my $host ( @temp_host )
  {
    my $fqdn   = $csa_hosts{$host}{'fqhn'};
    my $path   = $csa_hosts{$host}{'path'};
    my $access = $csa_hosts{$host}{'access'};
    my $miware = $test_hosts{$host}{'middware'};
    my $url    = $test_hosts{$host}{'url'};
    my $env_url= $test_hosts{$host}{'env_url'};
    $modules   = $test_hosts{$host}{'modules'};

    if ( $miware ) 
    {
        $cmd = "$access $fqdn 'mkdir -p $path;                                   ".
      " cd $path && test -d csa && (cd csa && svn up -q) || svn co $svn csa -q;  ".
      " $path/csa/csa_envset.pl \"$env_url\" \"$modules\";                       ".
      " source $path/csa/test_scripts/env.sh > /dev/null 2>&1;                   ".
      " $path/csa/csa_midtest.pl  $fqdn $miware $url $time $host'                "; 

      if ( 0 != system ($cmd) )
      {
        print " Error: Cannot complete CSA test\n";
        exit -1;
      }
    } 
  }
}

sub help (;$)
{
  my $ret = shift || 0;

  print <<EOT;

    $0 [-h|--help] 
       [-l|--list] 
       [-c|--check] 
       [-v|--version version=all] 
       [-n|--no]
       [-e|--exit|--error]
       [-f|--force]
       [-s|--show]
       [-d|--deploy]
       [-r|--remove]
       [-x|--execute] 
       [-u|--user id] 
       [-p|--pass pw] 
       [-t|--target all,host1,host2,...] 
       [-m|--module all,saga-core,readme,...] 
       [-j]--job all,pbs,gram,...]

    -h : this help message
    -l : list available target hosts
    -c : check csa access and tooling               (default: off)
    -v : version to deploy (see csa_packages file)  (default: trunk)
    -a : deploy SAGA on all known target hosts      (default: off)
    -u : svn user id                                (default: local user id)
    -p : svn password                               (default: "")
    -n : run 'make -n' to show what *would* be done (default: off)
    -s : show commands to be run                    (default: off)
    -e : exit on errors                             (default: off)
    -f : force re-deploy                            (default: off)
    -d : deploy version/modules on targets          (default: off)
    -r : remove deployment on target host           (default: off)
    -x : for maintainance, use with care!           (default: off)
    -t : target hosts to deploy on                  (default: all)
    -m : modules to deploy                          (default: all)
    -j : submit test jobs                           (default: off)
EOT
  exit ($ret);
}

