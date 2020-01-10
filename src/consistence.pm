#!/usr/bin/perl
#
# consistence.pm
#
# (C) Copyright IBM Corp. 2003, 2009
#
# THIS FILE IS PROVIDED UNDER THE TERMS OF THE ECLIPSE PUBLIC LICENSE
# ("AGREEMENT"). ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS FILE
# CONSTITUTES RECIPIENTS ACCEPTANCE OF THE AGREEMENT.
#
# You can obtain a current copy of the Eclipse Public License from
# hhttp://www.opensource.org/licenses/eclipse-1.0.php
#
# Author:       Heidi Neumann <heidineu@de.ibm.com>
# Contributors: 
#
# Description:
# This perl script contains the functions to test the varios types of
# consistence.
#

package consistence;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(compareNumberOfInstances 
	     comparePropertyValue
	     compareInstanceValues 
	     checkReferences);

use strict;
use warnings;

use cimom;

sub wbem_cli {
  my ($cmd,$parm) = @_;
  my @enum  = ();
  my $e = $ENV{'SBLIM_TESTSUITE_VERBOSE'};
  if (defined $e) { print "\n>>${cmd} ${parm}<<\n"; }
  @enum = `${cmd} ${parm} 2>&1`;
  return @enum
}


#******************************************************************************#
# ReturnCode Description :
#
# 1  ... SUCCESS
#
# 2  ... Enumeration : Exception occured
# 3  ... Enumeration : returned Instances was not of the class type, that was 
#                      asked for in parameter ${class} -> Provider failure ?
#

my $CLASS="";
my $INPUT_FILE;

my $REPORT_FILE;
my $OLD_HDL;             # save file handle of STDOUT; necesarry when report file is generated

my $keyname;
my $keyval;
my $inst;
my $checkRef_ain;
my $checkRef_gi;
my $sourceClass;
my $targetClass;

my @rc = (0,"");


#******************************************************************************#
# call enumInstanceNames of a certain class, count the number of instances and
# compare the value with an expected value (min, equal, max)
#
# @rc = ( $ReturnCode, 
#         $ReturnCodeDescription,
#         $NumberOfInstances )
#

sub compareNumberOfInstances {
  my ($CLASS, $op, $value, $volatile) = @_;
  print "$CLASS --- check number of instances started ";
  $|=1;
  @rc = (0,"",0);

  @rc = &numberOfInstances($CLASS);

  return @rc if ( $rc[0] != 1 );

  if ( $op =~ /equal/i ) {
    if ( !($rc[2] eq $value) ) {  
      if ( ! defined $volatile ) {  
        $rc[0]=3;
	$rc[1]="failed ... counted CIM instances $rc[2] not $op system value $value" ;
	print "... $op ... failed\n";
	return @rc;
      }
      elsif ( defined $volatile ) {  
        $rc[0]=6;
	$rc[1]="warning ... counted CIM instances $rc[2] not $op system value $value" ;
	print "... $op ... warning\n";
	return @rc;
      }
    }
    $rc[1]="ok ... counted CIM instances $rc[2] $op system value $value" if ( $rc[2] eq $value );
  }

  elsif ( $op =~ /less than/i ) {
    if ( $rc[2] >= $value ) { 
      if ( ! defined $volatile ) {     
        $rc[0]=4;
	$rc[1]="failed - counted CIM instances $rc[2] not $op system value $value";
	print "... $op ... failed\n";
	return @rc;
      }
      elsif ( defined $volatile ) {      
        $rc[0]=7;
	$rc[1]="warning - counted CIM instances $rc[2] not $op system value $value";
	print "... $op ... warning\n";
	return @rc;
      }
    }
    $rc[1]="ok ... counted CIM instances $rc[2] $op system value $value" if ( $rc[2] < $value );
  }

  elsif ( $op =~ /greater than/i ) {
    if ( $rc[2] <= $value ) { 
      if ( ! defined $volatile ) {      
        $rc[0]=5;
	$rc[1]="failed - counted CIM instances $rc[2] not $op system value $value";
	print "... $op ... failed\n";
	return @rc;
      }
      elsif ( defined $volatile ) {      
        $rc[0]=8;
	$rc[1]="warning - counted CIM instances $rc[2] not $op system value $value";
	print "... $op ... warning\n";
	return @rc;  
      }
    }
    $rc[1]="ok ... counted CIM instances $rc[2] $op system value $value" if ( $rc[2] > $value );
  }

  print "... $op ... ok\n";
  return @rc;
}



sub numberOfInstances {
  my ($CLASS) = @_;
  my @enum  = ();
  my $count = 0;
  $|=1;

  @enum = `wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${CLASS} 2>&1`;
  $rc[3] = "wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${CLASS}";

  if( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/$cimom::ERROR_PREFIX|exception/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration - exception occured - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  print ".";

  foreach my $elem (@enum) {
    $count++;
  }

  $rc[0]=1;
  $rc[2]=$count;

  return @rc;
}

#******************************************************************************#




#******************************************************************************#
# call enumInstanceNames of a certain class and compare the value of property
# name with the expected value (min, equal, max, strcmp)
#
# @rc = ( $ReturnCode, 
#         $ReturnCodeDescription )
#

sub comparePropertyValue {
  my ($CLASS, $op, $name, $value, $volatile) = @_;
  print $CLASS." --- check property value of $name started ";
  my @enum  = ();
  my $cimval="";
  $|=1;
  @rc = (0,"");

  @enum = `wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${CLASS} 2>&1`;
  $rc[3] = "wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${CLASS}";

  if( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/$cimom::ERROR_PREFIX/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration - exception occured - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  print ".";

  foreach my $elem (@enum) {

    chomp($elem);
    my @get = wbem_cli("wbemgi -nl", "${cimom::WBEMFLAG} '${cimom::PROTOCOL}${elem}'");
    if( defined $get[0] && defined $get[1] ) {
      if ( !(defined $volatile) && $get[0]=~/\*/ && $get[1]=~/$cimom::ERROR_PREFIX/i) {
        $rc[0]=2;
	chomp($get[1]);
	$get[1] =~ s/\* //;
	$rc[1]="failed - getInstance - exception occured - $get[1]";
	print "... failed\n";
	return @rc;
      }
      elsif ( defined $volatile && $get[1]=~/CIM_ERR(?!_NOT_FOUND)/i ) {
	next;
      }
    }

    foreach my $get (@get) {
      chomp($get);
      if( $get =~ /(\-$name\=(.*))+/i ) {
	$cimval=$2;
	$cimval =~ s/\\//g;
	$cimval =~ s/\"//g;
	$value  =~ s/\"//g;
      }
      # empty property
      elsif( $get =~ /\-$name$/i ) {
	$cimval=$name;
      }
    }

    # specified property not found
    if($cimval eq "") {
      $rc[0]=3;
      $rc[1]="failed ... $name not found in CIM Instance $elem";
      print "... $op ... failed\n";
      return @rc;
    }

    if ( $op =~ /equal/i ) {
      if ( defined $cimval && !($cimval eq $value) && !( uc $cimval eq $value) && !( $cimval eq uc $value) && !( ($cimval eq "") && ($value eq "NULL")) ) {
        if( ! defined $volatile ) {
	  $rc[0]=4;
	  $rc[1]="failed - property $name value $cimval not $op $value";
	  print "... $op ... failed\n";
	  return @rc;
        } elsif ( defined $volatile ) {
          $rc[1]="warning - property $name value $cimval not $op $value";
          print "... $op ... warning\n";
          return @rc;
        }
      }
      $rc[1]="ok ... property $name value was : $cimval" if ( $cimval eq $value );
    } 

    elsif ( $op =~ /less than/i ) {
      if ( defined $cimval && $cimval >= $value ) {      
        $rc[0]=5;
	$rc[1]="failed - property $name value $cimval not $op $value";
	print "... $op ... failed\n";
	return @rc;
      }
      $rc[1]="ok ... property $name value $cimval $op $value"  if ( $cimval < $value );
    }

    elsif ( $op =~ /greater than/i ) {
      if ( defined $cimval && $cimval <= $value ) {      
	$rc[0]=6;
	$rc[1]="failed - property $name value $cimval not $op $value";
	print "... $op ... failed\n";
	return @rc;
      }
      $rc[1]="ok ... property $name value $cimval $op $value"  if ( $cimval > $value );
    }

    elsif ( $op =~ /grep/i ) {
      if (  defined $cimval && ($cimval !~ /$value/) ) {      
	$rc[0]=7;
	$rc[1]="failed ... property $name value $cimval doesn't grep to $value ";
	print "... $op ... failed\n";
	return @rc;
      }
      $rc[1]="ok ... property $name value set to : $cimval";
    }

    elsif ( $op =~ /set/i ) {
      if ( ! defined $cimval || (defined $cimval && ($cimval eq $name)) ) {      
	$rc[0]=8;
	$rc[1]="failed ... property $name value not set";
	print "... $op ... failed\n";
	return @rc;
      }
      $rc[1]="ok ... property $name value set to : $cimval";
    }

    elsif ( $op =~ /empty/i ) {   
	if( defined $cimval && !($cimval eq $name) && !($cimval eq "NULL")) {
	$rc[0]=9;
	$rc[1]="failed ... property $name value set to : $cimval";
	print "... $op ... failed\n";
	return @rc;
      }
      $rc[1]="ok ... property $name value not set";
    }

  }

  $rc[0]=1;

  print "... $op ... ok\n";
  return @rc;
}



#******************************************************************************#
# call enumInstanceNames of a certain class and compare if the values of 
# property names are equal to the expected values
#
# @rc = ( $ReturnCode, 
#         $ReturnCodeDescription )
#

sub compareInstanceValues {
  my ($input,$class, $names, $volatile) = @_;
  $CLASS=$class;
  print "$CLASS --- check property values on instance level started ";
     @rc      = (0,"");
  my @enum    = ();
  my $cimval  = "";
  my @names   = split(' ',$names);
  my $count   = 0;
  $keyname = $names[0];
  my @vals    = ();
  my $line;
  my $valid   = 0;
  my $failed  = 0;
  my $warning = 0;
  $|=1;

  unlink("stat/$CLASS.instance");

  @enum = `wbemei ${cimom::WBEMFLAG} ${cimom::HOST}${CLASS} 2>&1`;
  $rc[3] = "wbemei ${cimom::WBEMFLAG} ${cimom::HOST}${CLASS}";

  if( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/$cimom::ERROR_PREFIX/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration - exception occured - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  print ".";

  foreach my $elem (@enum) {

    $elem = removeObjectPathFromInstance($elem);

    # find string properties within the property list (are quoted)
    if ( $elem =~ /((?<=\.|\,|\s)$keyname\=\"(.*?)(?=\,|\"\,|\"\n|\n))+/i ) {
      $keyval=$2;
      $keyval =~ s/\\//g;
    }
    # find string properties at the end of the property list (are quoted)
    elsif ( $elem =~ /((?<=\.|\,|\s)$keyname\=\"(.*?)(?=\"))+/i ) {
      $keyval=$2;
      $keyval =~ s/\\//g;
    }

    # find non string properties within the property list
    elsif ( $elem =~ /((?<=\.|\,|\s)$keyname\=(.*?)(?=\,))+/i ) {
      $keyval=$2;
    }
    # find non string properties at the end of the property list
    elsif ( $elem =~ /((?<=\.|\,|\s)$keyname\=(.*))+/i ) {
      $keyval=$2;
    }

    # find properties with no value
    elsif ( $elem =~ /((?<=\.|\,|\s)$keyname(?=\,|\n))+/i ) {
      $keyval=$keyname;
    }

    # specified property not found
    else {
      $rc[0]=3;
      $rc[1]="failed ... $keyname not found in CIM Instance $elem";
      print "... failed\n";
      return @rc;
    }

    open(INPUT_FILE, "$input") or 
	die "can not open Instance Input File $input for $CLASS";

    while ( $line = <INPUT_FILE> ) {
      chomp($line);
      if( $line =~ /^$keyval$/i ) { 
	$valid = 1;
	$vals[0] = $line;
	my $i=1;
	for ( $i .. $#names ) {
	  $vals[$i] = <INPUT_FILE>;
	  chomp($vals[$i]);
	  $i++;
	}
	goto checkInst; 
      }
      else {
	for ( 0 .. $#names ) {
	  $line = <INPUT_FILE>;
	}
      }
    }

 checkInst:
    if ( $valid == 1 ) {
      foreach my $name (@names) {

	# find string properties within the property list (are quoted)
	if ( $elem =~ /((?<=\.|\,|\s)$name\=\"(.*?)(?=\,|\"\,|\"\n|\n))+/i ) {
	  $cimval=$2;
	  $cimval =~ s/\\//g;
        }
	# find string properties at the end of the property list (are quoted)
	elsif ( $elem =~ /((?<=\.|\,|\s)$name\=\"(.*?)(?=\"))+/i ) {
	  $cimval=$2;
	  $cimval =~ s/\\//g;
	}

	# find non string properties within the property list
	elsif ( $elem =~ /((?<=\.|\,|\s)$name\=(.*?)(?=\,))+/i ) {
	  $cimval=$2;
	}
	# find non string properties at the end of the property list
	elsif ( $elem =~ /((?<=\.|\,|\s)$name\=(.*))+/i ) {
	  $cimval=$2;
	}
	
	# find properties with no value
	elsif ( $elem =~ /((?<=\.|\,|\s)$name(?=\,|\n))+/i ) {
	  $cimval=$name;
	}
	
        # specified property not found
	else {
	  $rc[0]=5;
	  $rc[1]="failed ... $name not found in CIM Instance $elem";
	  print "... failed\n";
	  return @rc;
        }

	# compare value of property with system value
	if ( defined $cimval && !($cimval eq $vals[$count]) 
	     && !( uc $cimval eq $vals[$count]) && !( $cimval eq uc $vals[$count]) 
	     && !( ($cimval eq "") && ($vals[$count] eq "NULL")) ) {
          if( ! defined $volatile ) {
	    $rc[0]=6;
	    $rc[1]="failed ... property $name value $cimval not equal to system value $vals[$count]";
	    $failed++;
          }
          elsif ( defined $volatile ) {
 	    $rc[0]=7;
	    $rc[1]="warning ... property $name value $cimval not equal to system value $vals[$count]";
	    $warning++;
          }
          &consistence_inst_write_report();
        }
	$count++;
      }
    }
    else {
      if( ! defined $volatile ) {
        $rc[0]=4;
	$rc[1]="failed ... instance with key $keyname = $keyval not found";
	$failed++;
      }
      elsif ( defined $volatile ) {
        $rc[0]=7;
	$rc[1]="warning ... instance with key $keyname = $keyval not found";
	$warning++;
      }
      &consistence_inst_write_report();
    }
    $count=0;
    @vals = ();
    $valid = 0;
  }

  if ( $rc[0]!=0 ) { 
    if ( defined $volatile && ($failed==0) && ($warning!=0) ) {
      $rc[1]="warning ... check stat/$CLASS.instance for more information"; 
      print "... warning ... check stat/$CLASS.instance for more information\n";
    }
    elsif ( $failed!=0 ) {
      $rc[0]=8; 
      $rc[1]="failed ... check stat/$CLASS.instance for more information"; 
      print "... failed ... check stat/$CLASS.instance for more information\n";
    }
  }
  else { 
    $rc[0]=1; 
    $rc[1]="ok"; 
    print "... ok\n";
  }
  return @rc;
}



#******************************************************************************#
# call enumInstanceNames of the source class to get the objectpathes -> used as
# input parameter; call associators, count the number of referenced objects and
# compare the value with an expected value (min, equal, max)
#
# @rc = ( $OK, 
#         $FAILED )
#

sub checkReferences {
  my ($class,$op,$source,$target,$value,$volatile) = @_;
  $CLASS=$class;
  $sourceClass=$source;
  $targetClass=$target;
  print "$CLASS --- $sourceClass to $targetClass - check referenced objects started ";
  my $count = 0;
     @rc    = (1,"ok",1,"ok");
  my @lrc   = (0,0);
  my @assoc;
  my $failed  = 0;
  my $warning = 0;
  $|=1;

#  my @enum = `2>&1 wbemein ${cimom::HOST}${sourceClass}`;
  my @enum = wbem_cli("wbemein", "${cimom::WBEMFLAG} ${cimom::HOST}${sourceClass}");
  if ( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/$cimom::ERROR_PREFIX|exception/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration $sourceClass - exception occurred - $enum[1]";
      &consistence_assoc_write_report();
      $lrc[1]++;
      print "... failed\n";
      return @lrc;
    }
  }
  &consistence_assoc_write_report();

  foreach my $elem (@enum) {
    print ".";
    @rc    = (1,"ok",1,"ok");
    $count=0;
    chomp($elem);
    $inst = $elem;

#    @assoc = `2>&1 wbemai -ac $CLASS -arc $targetClass '${cimom::PROTOCOL}${elem}'`;
    @assoc = wbem_cli("wbemai", "${cimom::WBEMFLAG} -ac $CLASS -arc $targetClass '${cimom::PROTOCOL}${elem}'");
    $checkRef_ain = "wbemai ${cimom::WBEMFLAG} -ac $CLASS -arc $targetClass '${cimom::PROTOCOL}${elem}'";

    if( defined $assoc[0] && defined $assoc[1]) {
      if ( $assoc[0]=~/\*/ && $assoc[1]=~/$cimom::ERROR_PREFIX|exception/i) {	
	chomp($assoc[1]);
	$assoc[1] =~ s/\* //;
	if ( ! defined $volatile ) {
	  $rc[2]=12;
	  $rc[1]="failed - exception occurred - $assoc[1]";
	  $lrc[1]++;
	  print "... failed\n";
        }
	else {
	  $rc[2]=11;
	  $rc[1]="warning - volatile class type returned with exception - $assoc[1]";
	  $lrc[0]++;
	  print "... warning\n";
	}
	&consistence_ref_write_report();
	return @lrc;
      }
    }

    foreach my $assoc (@assoc) {
      print ".";
      $count++;

      if ( $assoc =~ /^(.*?)\s/ ) {
	my $path = $1;   
#	my @get = `2>&1 wbemgi '${cimom::PROTOCOL}${path}'`;
	my @get = wbem_cli("wbemgi", "${cimom::WBEMFLAG} '${cimom::PROTOCOL}${path}'");
	$checkRef_gi = "wbemgi ${cimom::WBEMFLAG} '${cimom::PROTOCOL}${path}'";

	if ( defined $get[0]) {
	  chomp($get[0]);

	  # if $get[1] contains no value, no exception occurred
	  if ( ! defined $get[1] ) {
	    if ( ! $get[0]=~/$targetClass\./i ) {
	      $rc[2]=13;
	      $rc[3]="failed - returned instance is of wrong class type - $get[0]";
	      $failed++;
	      $count--;
	    }
	    elsif ( $get[0] eq $assoc ) {
	      $rc[2]=14;
	      $rc[3]="failed - instances are not equal - $get[0]";
	      $failed++;
	      $count--;
	    }
          }
	  # if $get[1] is defined an exception occurred; we have to figure out, which one
	  elsif ( defined $get[1] ) {
	    chomp($get[1]);
	    $get[1] =~ s/\* //g;
	    if ( $get[1]=~/$cimom::ERROR_PREFIX|exception/i ) {
	      if ( ! defined $volatile ) {
		$rc[2]=15;	  
		$rc[3]="failed - exception occurred - $get[1]";
		$failed++;
		$count--;
	      }
	      elsif ( defined $volatile && $get[1]=~/CIM_ERR(?!_NOT_FOUND)/i ) {
	        $rc[2]=16;
		$rc[3]="warning - volatile class type returned with exception - $get[1]";
		$warning++;
		$count--;
	      }
	    }
          }
        } 
      }
    }
    if ( $count == 0 ) {
      $rc[2]=1; 
      $rc[3]="ok ... cause : no instances referenced ;-)";
      $checkRef_gi="wbemgi was not run since either wbemai returned 0 instances, or all the instances returned had errors.";
    }

    if ( $op =~ /equal/i ) {
      if ( !($count eq $value) ) {  
	if ( ! defined $volatile ) {  
	  $rc[0]=3;
	  $rc[1]="failed ... counted CIM instances $count not $op system value $value";
	  $failed++;
        }
	elsif ( defined $volatile ) {  
	  $rc[0]=6;
	  $rc[1]="warning ... counted CIM instances $count not $op system value $value";
	  $warning++;
        }
      }
      $rc[1]="ok ... counted CIM instances $count $op system value $value" if ( $count eq $value );
    }
    
    elsif ( $op =~ /less than/i ) {
      if ( $count >= $value ) { 
	if ( ! defined $volatile ) {     
	  $rc[0]=4;
	  $rc[1]="failed - counted CIM instances $count not $op system value $value";
	  $failed++;
        }
	elsif ( defined $volatile ) {      
	  $rc[0]=7;
	  $rc[1]="warning - counted CIM instances $count not $op system value $value";
	  $warning++;
        }
      }
      $rc[1]="ok ... counted CIM instances $count $op system value $value" if ( $count < $value );
    }

    elsif ( $op =~ /greater than/i ) {
      if ( $count <= $value ) { 
	if ( ! defined $volatile ) {      
	  $rc[0]=5;
	  $rc[1]="failed - counted CIM instances $count not $op system value $value";
	  $failed++;
        }
	elsif ( defined $volatile ) {      
	  $rc[0]=8;
	  $rc[1]="warning - counted CIM instances $count not $op system value $value";
	  $warning++;
        }
      }
      $rc[1]="ok ... counted CIM instances $count $op system value $value" if ( $count > $value );
    }
    &consistence_ref_write_report();
  }

  $lrc[0]++ if(  $rc[0]==1 );
  $lrc[1]++ if( ($rc[0]!=1 ) && 
		($rc[0]!=0 ) &&  
		($rc[0]!=6 ) &&  
		($rc[0]!=7 ) &&  
		($rc[0]!=8 ) &&  
		($rc[0]!=16)   );
  $lrc[0]++ if(  $rc[2]==1);
  $lrc[1]++ if( ($rc[2]!=1 ) && 
		($rc[2]!=0 ) &&  
		($rc[2]!=6 ) &&  
		($rc[2]!=7 ) &&  
		($rc[2]!=8 ) &&  
		($rc[2]!=16)   );

  if(defined $volatile) {
    if ( $warning != 0) { print "... warning\n"; }
    elsif ( $failed != 0 ) { print "... failed\n"; }
    else { print "... ok\n" if( $lrc[1] == 0 ); }
  }
  else {
    print "... ok\n" if( $lrc[1] == 0 );
    print "... failed\n" if( $lrc[1] != 0 );
  }

  return @lrc;
}



#******************************************************************************#
# module internal sub function
# removes the object path information from an instance as delivered by wbemcli
#

sub removeObjectPathFromInstance {
  my ($elem) = @_;

  my @array = split('\,',$elem);
  my $keyCount = 0;
  my $lastKeyName;
  my $lastKeyValue;

  foreach my $array (@array) {
    $keyCount++;
    if( $array =~ /\s/ ) {
      if( $array =~ /(.+)(?<!\\)=(.+)/ ) {
	my $v1 = $1;
	my $v2 = $2;
	if( $v1 =~ /(.+)(?<!\\)=(.+)/ ) {
	  # both properties have values
	  $lastKeyName=$1;
	  $v2 = $2;
        }
	else {
	  $lastKeyName=$1;
        }
	# $v2 contains the lastKeyValue and the name of the first instance property
	# or a string with a whitespace
	if( $v2 =~ /\s/ ) {
	  if( $v2 =~ /^\"(.+)\"$/ ) {
            # ignore 
	  }
	  else {
	    # end of object path
	    $lastKeyValue = $v2;
	    $lastKeyValue =~ s/(.+)\s(.+)/$1/;
	    goto removeObjectPath;
	  }
        }
      }
    }
  }

  removeObjectPath:
#    print "\nkeyCount : $keyCount";
#    print "\nlastKeyName : $lastKeyName";	  
#    print "\nlastKeyValue : $lastKeyValue";
    my $c = 0;
    @array = split('\,',$elem);
    while ( $c < $keyCount ) {
      $array[$c] =~ s/\\/\\\\/;
      $array[$c] =~ s/\*/\\*/;
      $array[$c] =~ s/\?/\\?/;
      $array[$c] =~ s/\+/\\+/;
      $array[$c] =~ s/\{/\\{/;
      $array[$c] =~ s/\}/\\}/;
      if( $c < ($keyCount-1) ) {
	  $elem =~ s/^$array[$c]\,//;
      }
      else {
	$elem =~ s/^$lastKeyName\=$lastKeyValue//;
      }
      $c++;
    }
#    print "\nelem : $elem\n";
    return $elem;
}


#******************************************************************************#
#                                                                              #
# Definition of Report File for Instance Test                                  #
#                                                                              #
#******************************************************************************#

sub consistence_inst_write_report {
  # open Report File for this Class; if necessary one is created
  $REPORT_FILE="stat/$CLASS.instance";
  $^="CONSISTENCE_INST_TOP";
  $~="CONSISTENCE_INST";
  open(CONSISTENCE_INST,">> $REPORT_FILE") or die "can not create Report File for $CLASS";
  $OLD_HDL = select(CONSISTENCE_INST);
  write;
  close(CONSISTENCE_INST);
  select($OLD_HDL);
}

#******************************************************************************#
# Header
#

format CONSISTENCE_INST_TOP =
********************************************************************************
class : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
localtime()."\n";

--------------------------------------------------------------------------------

.

#******************************************************************************#
# Line
#

format CONSISTENCE_INST =
Key : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$keyname, $keyval if (defined $keyname)
RC     : @<<<<<<<<<<<<<
$rc[0] if (defined $rc[0])
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])

.

#******************************************************************************#






#******************************************************************************#
#                                                                              #
# Definition of Report File for Instance Test                                  #
#                                                                              #
#******************************************************************************#

sub consistence_assoc_write_report {
  # open Report File for this Class; if necessary one is created
  $REPORT_FILE="stat/$CLASS.system";
  $^="CONSISTENCE_ASSOC_TOP";
  $~="CONSISTENCE_ASSOC";
  open(CONSISTENCE_ASSOC,">> $REPORT_FILE") or die "can not create Report File for $CLASS";
  $OLD_HDL = select(CONSISTENCE_ASSOC);
  write;
  close(CONSISTENCE_ASSOC);
  select($OLD_HDL);
}

#******************************************************************************#
# Header
#

format CONSISTENCE_ASSOC_TOP =
********************************************************************************
association : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
localtime()."\n";

.

#******************************************************************************#
# Line
#

format CONSISTENCE_ASSOC =
********************************************************************************
sourceClass : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$sourceClass if (defined $sourceClass)
targetClass : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$targetClass if (defined $targetClass)
RC     : @<<<<<<<<<<<<<
$rc[0] if (defined $rc[0])
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])

.

#******************************************************************************#




#******************************************************************************#
#                                                                              #
# Definition of Report File for Association Test of referenced instances       #
#                                                                              #
#******************************************************************************#

sub consistence_ref_write_report {
  # open Report File for this Class; if necessary one is created
  $REPORT_FILE="stat/$CLASS.system";
  $^="CONSISTENCE_REF_TOP";
  $~="CONSISTENCE_REF";
  open(CONSISTENCE_REF,">> $REPORT_FILE") or die "can not create Report File for $CLASS";
  $OLD_HDL = select(CONSISTENCE_REF);
  write;
  close(CONSISTENCE_REF);
  select($OLD_HDL);
}

#******************************************************************************#
# Header
#

format CONSISTENCE_REF_TOP =
.

#******************************************************************************#
# Line
#

format CONSISTENCE_REF =
--------------------------------------------------------------------------------
source : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$inst if (defined $inst)

check number of returned references : RC @<<<<<<<<<<<<<
$rc[0] if (defined $rc[0])
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])
last executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$checkRef_ain if(defined $checkRef_ain);

check returned referenced instances : RC @<<<<<<<<<<<<<
$rc[2] if (defined $rc[2])
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[3] if (defined $rc[3])
last executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$checkRef_gi if(defined $checkRef_gi);

.

#******************************************************************************#


1;

#******************************************************************************#

# end of module consistence.pm
