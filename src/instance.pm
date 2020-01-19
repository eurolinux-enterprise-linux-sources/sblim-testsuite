#!/usr/bin/perl
#
# instance.pm
#
# (C) Copyright IBM Corp. 2003, 2009
#
# THIS FILE IS PROVIDED UNDER THE TERMS OF THE ECLIPSE PUBLIC LICENSE
# ("AGREEMENT"). ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS FILE
# CONSTITUTES RECIPIENTS ACCEPTANCE OF THE AGREEMENT.
#
# You can obtain a current copy of the Eclipse Public License from
# http://www.opensource.org/licenses/eclipse-1.0.php
#
# Author:       Heidi Neumann <heidineu@de.ibm.com>
# Contributors: 
#
# Description:
# This perl script contains the functions to test the implemented
# interface of an Instance Provider.
#

package instance;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(enumerate get create delete modify
	     check_returnedException);

use strict;
use warnings;

use cimom;


#******************************************************************************#
# ReturnCode Description :
#
# 1  ... SUCCESS
#
# 2  ... Enumeration : Exception occured
# 3  ... Enumeration : returned Instances was not of the class type, that was 
#                      asked for in parameter ${class} -> Provider failure ?
#
# 12 ... Get         : Exception occured and return code did not match with the 
#                      acceoted return code
# 13 ... Get         : returned Instances was not of the class type, that was  
#                      asked for in parameter ${class} -> Provider failure ?
#

sub wbem_cli {
  my ($cmd,$parm) = @_;
  my @enum  = ();
  my $e = $ENV{'SBLIM_TESTSUITE_VERBOSE'};
  if (defined $e) { print "\n>>${cmd} ${parm}<<\n"; }
  @enum = `${cmd} ${parm} 2>&1`;
  return @enum
}

#******************************************************************************#
# call enumInstances or enumInstanceNames of a certain class
#
# @rc = ( $ReturnCode, $ReturnCodeDescription,
#         $UserTime, $SystemTime, 
#         $ChildUserTime, $ChildSystemTime, 
#         $NumberOfInstances )
#

sub enumerate {
  my ($class, $op) = @_;
  my @stexec = times();
  print $class." --- $op() started ";
  my @enum  = ();
  my $count = 0;
  my @rc = (0,"");
  $|=1;

#  if    ( $op =~ /enumInstanceNames/) { @enum = `wbemein ${cimom::HOST}${class} 2>&1`; 
  if    ( $op =~ /enumInstanceNames/) { @enum = wbem_cli("wbemein", "${cimom::WBEMFLAG} ${cimom::HOST}${class}"); 
					$rc[7]= "wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${class}";
				      }
#  elsif ( $op =~ /enumInstances/ )    { @enum = `wbemei ${cimom::HOST}${class} 2>&1`;  
  elsif ( $op =~ /enumInstances/ )    { @enum = wbem_cli("wbemei", "${cimom::WBEMFLAG} ${cimom::HOST}${class}");  
					$rc[7]= "wbemei ${cimom::WBEMFLAG} ${cimom::HOST}${class}"; 
				      }
  else { 
    print "... failed\n";
    return @rc; 
  }

  if( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/${cimom::ERROR_PREFIX}/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - exception occured - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  foreach my $elem (@enum) {
    print ".";
    $count++;
    if (!($elem=~/$class\./i)) {
      $rc[0]=3;
      $rc[1]="failed - returned instance(s) is/are of wrong class type";
      print "... failed\n";
      return @rc;
    }
  }
  $rc[0]=1;
  $rc[1]="ok";

  my @texec = times();
  $rc[2]=$texec[0]-$stexec[0];
  $rc[3]=$texec[1]-$stexec[1];
  $rc[4]=$texec[2]-$stexec[2];
  $rc[5]=$texec[3]-$stexec[3];

  $rc[6]=$count;

  print "... ok\n";
  return @rc;
}

#******************************************************************************#



#******************************************************************************#
# Execute getInstance for each instance, which was returned by the enumeration
# of this class. It can be, that an instance is not available, when getInstance 
# is called. Therefore the paramter $rc_ok needs to be filled with an return 
# value, which is accepted as ok.
#

sub get {
  my ($class, $volatile) = @_;
  my @stexec = times();
  print $class." --- get() started ";
#  my @enum  = `wbemein ${cimom::HOST}${class} 2>&1`;
  my @enum  = wbem_cli("wbemein","${cimom::WBEMFLAG} ${cimom::HOST}${class}");
  my @rc = (0,"");
  $rc[7]= "wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${class}";
  $|=1;

  if( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/${cimom::ERROR_PREFIX}/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration - exception occured - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  foreach my $elem (@enum) {
    print ".";
    if (!($elem=~/$class\./i)) {
      $rc[0]=3;
      $rc[1]="failed - enumeration - returned instance(s) is/are of wrong class type";
      print "... failed\n";
      return @rc;
    }

    chomp($elem);
    my @get = `2>&1 wbemgi ${cimom::WBEMFLAG} '${cimom::PROTOCOL}${elem}'`;
    $rc[7]= "wbemgi ${cimom::WBEMFLAG} '${cimom::PROTOCOL}${elem}'";

    # if $get[1] contains no value, no exception occurred
    if ( ! defined $get[1] ) {
      if ( ! $get[0]=~/$class\./i ) {
	$rc[0]=13;
	$rc[1]="failed - returned instance is of wrong class type - $get[0]";
	print "... failed\n";
	return @rc;
      }
    }

    # if $get[1] is defined an exception occurred; we have to figure out, which one
    if ( defined $get[1] ) {
      chomp($get[1]);
      $get[1] =~ s/\* //g;
      if ( $get[1]=~/${cimom::ERROR_PREFIX}/i ) {
	if ( ! defined $volatile ) {
	  $rc[0]=12;	  
	  $rc[1]="failed - exception occurred - $get[1]";
	  print "... failed\n";
	  return @rc;
        }
	if ( defined $volatile && 
	     $get[1]=~/${cimom::ERROR_PREFIX}!{NOT_FOUND}/i ) {
	  $rc[0]=14;
	  $rc[1]="warning - volatile class type returned with exception - $get[1]";
	  print "... warning\n";
	  return @rc;
	}
      }
    } 
  }
  $rc[0]=1;
  $rc[1]="ok";

  my @texec = times();
  $rc[2]=$texec[0]-$stexec[0];
  $rc[3]=$texec[1]-$stexec[1];
  $rc[4]=$texec[2]-$stexec[2];
  $rc[5]=$texec[3]-$stexec[3];

  print "... ok\n";
  return @rc;
}

#******************************************************************************#



#******************************************************************************#
# Execute createInstance.
#

sub create {
  my ($class, $input) = @_;
  my @stexec = times();
  print $class." --- create() started ";
  my $var = $input;
  $var =~ s/$class\.//;
  my @rc = (0,"");
#  my @rv  = `wbemci ${cimom::WBEMFLAG} '${cimom::HOST}$input' $var 2>&1`;
  my @rv  = wbem_cli("wbemci", "${cimom::WBEMFLAG} '${cimom::HOST}$input' $var");
  $rc[7]= "wbemci ${cimom::WBEMFLAG} '${cimom::HOST}$input' $var";
  $|=1;

  # if $rv[1] is defined an exception occurred; we have to figure out, which one
  if ( defined $rv[1] ) {
    chomp($rv[1]);
    $rv[1] =~ s/\* //g;
    if ( $rv[1]=~/${cimom::ERROR_PREFIX}/i ) {
      $rc[0]=2;
      $rc[1]="failed - exception occurred -  $rv[1]";
      print "... failed\n";
      return @rc;
    }
  }

  # getInstance to check if creation was really sucessfull
#  @rv  = `wbemgi ${cimom::WBEMFLAG} '${cimom::HOST}${input}' 2>&1`;
  @rv  = wbem_cli("wbemgi", "${cimom::WBEMFLAG} '${cimom::HOST}${input}'");

  # if $rv[1] contains no value, no exception occurred
  if ( ! defined $rv[1] ) {
    if ( ! $rv[0]=~/$input/i ) {
      $rc[0]=3;
      $rc[1]="failed - instance was not created";
      print "... failed\n";
      return @rc;
    }
  }

  # if $rv[1] is defined an exception occurred; we have to figure out, which one
  if ( defined $rv[1] ) {
    chomp($rv[1]);
    $rv[1] =~ s/\* //g;
    if ( $rv[1]=~/${cimom::ERROR_PREFIX}/i ) {
      $rc[0]=12;	  
      $rc[1]="failed - exception occurred - $rv[1]";
      print "... failed\n";
      return @rc;
    }
  }

  $rc[0]=1;
  $rc[1]="ok";

  my @texec = times();
  $rc[2]=$texec[0]-$stexec[0];
  $rc[3]=$texec[1]-$stexec[1];
  $rc[4]=$texec[2]-$stexec[2];
  $rc[5]=$texec[3]-$stexec[3];

  print "... ok\n";
  return @rc;
}


#******************************************************************************#



#******************************************************************************#
# Execute deleteInstance.
#

sub delete {
  my ($class,$input) = @_;
  my @stexec = times();
  print $class." --- delete() started ";
  my @rc = (0,"");
#  my @rv  = `wbemdi ${cimom::WBEMFLAG} '${cimom::HOST}${input}' 2>&1`;
  my @rv = wbem_cli("wbemdi", "${cimom::WBEMFLAG} '${cimom::HOST}${input}'");
  $rc[7]= "wbemdi ${cimom::WBEMFLAG} '${cimom::HOST}${input}'";
  $|=1;

  # if $rv[1] is defined an exception occurred; we have to figure out, which one
  if ( defined $rv[1] ) {
    chomp($rv[1]);
    $rv[1] =~ s/\* //g;
    if ( $rv[1]=~/${cimom::ERROR_PREFIX}/i ) {
      $rc[0]=2;
      $rc[1]="failed - exception occurred -  $rv[1]";
      print "... failed\n";
      return @rc;
    }
  }

  # getInstance to check if deletion was really sucessfull
#  @rv  = `wbemgi ${cimom::HOST}${input} 2>&1`;
  @rv  = wbem_cli("wbemgi","${cimom::WBEMFLAG} ${cimom::HOST}${input}");

  # if $rv[1] contains no value, no exception occurred
  if ( ! defined $rv[1] ) {
    if ( $rv[0]=~/$input/i ) {
      $rc[0]=3;
      $rc[1]="failed - instance was not deleted";
      print "... failed\n";
      return @rc;
    }
  }

  # if $rv[1] is defined an exception occurred; we have to figure out, which one
  if ( defined $rv[1] ) {
    chomp($rv[1]);
    $rv[1] =~ s/\* //g;
    if ( $rv[1]=~/${cimom::ERROR_PREFIX}/i && 
	 $rv[1]=~/${cimom::ERROR_PREFIX}!{NOT_FOUND}/i ) {
      $rc[0]=12;	  
      $rc[1]="failed - exception occurred - $rv[1]";
      print "... failed\n";
      return @rc;
    }
  }

  $rc[0]=1;
  $rc[1]="ok";

  my @texec = times();
  $rc[2]=$texec[0]-$stexec[0];
  $rc[3]=$texec[1]-$stexec[1];
  $rc[4]=$texec[2]-$stexec[2];
  $rc[5]=$texec[3]-$stexec[3];

  print "... ok\n";
  return @rc;
}


#******************************************************************************#



#******************************************************************************#
# Execute modifyInstance.
#

sub modify {
  my ($class, $input, $var) = @_;
  my @stexec = times();
  print $class." --- modify() started ";
#  my $var = $input;
#  $var =~ s/$class\.//;
  my @rc = (0,"");
#  my @rv  = `wbemci ${cimom::WBEMFLAG} '${cimom::HOST}$input' $var 2>&1`;
  my @rv  = wbem_cli("wbemmi", "${cimom::WBEMFLAG} '${cimom::HOST}$input' $var");
  $rc[7]= "wbemmi ${cimom::WBEMFLAG} '${cimom::HOST}$input' $var";
  $|=1;

  # if $rv[1] is defined an exception occurred; we have to figure out, which one
  if ( defined $rv[1] ) {
    chomp($rv[1]);
    $rv[1] =~ s/\* //g;
    if ( $rv[1]=~/${cimom::ERROR_PREFIX}/i ) {
      $rc[0]=2;
      $rc[1]="failed - exception occurred -  $rv[1]";
      print "... failed\n";
      return @rc;
    }
  }

  # TODO: do getInstance and check if the instance modification was really done  
  # @rv  = wbem_cli("wbemgi", "${cimom::WBEMFLAG} '${cimom::HOST}${input}'");

  # if $rv[1] is defined an exception occurred; we have to figure out, which one
  if ( defined $rv[1] ) {
    chomp($rv[1]);
    $rv[1] =~ s/\* //g;
    if ( $rv[1]=~/${cimom::ERROR_PREFIX}/i ) {
      $rc[0]=12;	  
      $rc[1]="failed - exception occurred - $rv[1]";
      print "... failed\n";
      return @rc;
    }
  }

  $rc[0]=1;
  $rc[1]="ok";

  my @texec = times();
  $rc[2]=$texec[0]-$stexec[0];
  $rc[3]=$texec[1]-$stexec[1];
  $rc[4]=$texec[2]-$stexec[2];
  $rc[5]=$texec[3]-$stexec[3];

  print "... ok\n";
  return @rc;
}


#******************************************************************************#



#******************************************************************************#
# check, if the return value, e.g. a certain Exception like "NOT_SUPPORTED" is 
# the expected one
#

sub check_returnedException {
  my ($class, $op, $rv, $input) = @_;
  my @stexec = times();
  print $class." --- $op() - test return Value - started ";
  my @enum = ();
  my @rc   = (0,"");
  $|=1;


  if( $op =~ /associators/ || $op =~ /associatorNames/ ||
      $op =~ /references/  || $op =~ /referenceNames/   ) {
#    @enum = `wbemein ${cimom::HOST}${input} 2>&1`;
    @enum = wbem_cli("wbemein", "${cimom::WBEMFLAG} ${cimom::HOST}${input}");
    $rc[9]= "wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${input}";
    $input=$enum[0];
    chomp($input);
    @enum=();
  }

  # ---------------------------- Instance Interface -------------------------- #
#  if    ( $op =~ /enumInstanceNames/) { @enum = `wbemein ${cimom::HOST}${class} 2>&1`; 
  if    ( $op =~ /enumInstanceNames/) { @enum = wbem_cli("wbemein", "${cimom::WBEMFLAG} ${cimom::HOST}${class}"); 
					$rc[7]= "wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${class}";
				      }
#  elsif ( $op =~ /enumInstances/ )    { @enum = `wbemei ${cimom::HOST}${class} 2>&1`;
  elsif ( $op =~ /enumInstances/ )    { @enum = wbem_cli("wbemei", "${cimom::WBEMFLAG} ${cimom::HOST}${class}");
					$rc[7]= "wbemei ${cimom::WBEMFLAG} ${cimom::HOST}${class}";
				      }
#  elsif ( $op =~ /get/ )              { @enum = `wbemgi ${cimom::WBEMFLAG} '${cimom::HOST}${input}' 2>&1`;
  elsif ( $op =~ /get/ )              { @enum = wbem_cli("wbemgi", "${cimom::WBEMFLAG} '${cimom::HOST}${input}'");
					$rc[7]= "wbemgi ${cimom::WBEMFLAG} '${cimom::HOST}${input}'";
				      }
  elsif ( $op =~ /create/ )           { 
    my $var = $input;
    $var =~ s/$class\.|\"//;
#    @enum = `wbemci ${cimom::WBEMFLAG} '${cimom::HOST}${input}' $var 2>&1`; 
    @enum = wbem_cli("wbemci", "${cimom::WBEMFLAG} '${cimom::HOST}${input}' $var"); 
    $rc[7]= "wbemci ${cimom::WBEMFLAG} '${cimom::HOST}${input}' $var"; 
  }
#  elsif ( $op =~ /delete/ )           { @enum = `wbemdi '${cimom::HOST}${input}' 2>&1`;
  elsif ( $op =~ /delete/ )           { @enum = wbem_cli("wbemdi", "${cimom::WBEMFLAG} '${cimom::HOST}${input}'");
					$rc[7]= "wbemdi ${cimom::WBEMFLAG} '${cimom::HOST}${input}'";
				      }
  elsif ( $op =~ /modify/ )           { 
    my $var = $input;
    $var =~ s/$class\.|\"//;
    @enum = wbem_cli("wbemmi", "${cimom::WBEMFLAG} '${cimom::HOST}${input}' $var"); 
    $rc[7]= "wbemmi ${cimom::WBEMFLAG} '${cimom::HOST}${input}' $var"; 
  }

  # -------------------------- Association Interface ------------------------- #
  elsif ( $op =~ /associators/)       { 
#    @enum = `wbemai -ac $class '${cimom::PROTOCOL}${input}' 2>&1`; 
    @enum = wbem_cli("wbemai", "${cimom::WBEMFLAG} -ac $class '${cimom::PROTOCOL}${input}'"); 
    $rc[9]= "wbemai ${cimom::WBEMFLAG} -ac $class '${cimom::PROTOCOL}${input}'";
  }
  elsif ( $op =~ /associatorNames/ )  { 
#    @enum = `wbemain -ac $class '${cimom::PROTOCOL}${input}' 2>&1`;
    @enum = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class '${cimom::PROTOCOL}${input}'");
    $rc[9]= "wbemain -ac $class ${cimom::WBEMFLAG} '${cimom::PROTOCOL}${input}' ";
  }
  elsif ( $op =~ /references/)        { 
#    @enum = `wbemri -arc $class '${cimom::PROTOCOL}${input}' 2>&1`;
    @enum = wbem_cli("wbemri", "${cimom::WBEMFLAG} -arc $class '${cimom::PROTOCOL}${input}'");
    $rc[9]= "wbemri -arc $class ${cimom::WBEMFLAG} '${cimom::PROTOCOL}${input}'";
  }
  elsif ( $op =~ /referenceNames/ )   { 
#    @enum = `wbemrin -arc $class '${cimom::PROTOCOL}${input}' 2>&1`; 
    @enum = wbem_cli("wbemrin", "${cimom::WBEMFLAG} -arc $class '${cimom::PROTOCOL}${input}'"); 
    $rc[9]= "wbemrin ${cimom::WBEMFLAG} -arc $class '${cimom::PROTOCOL}${input}'";
  }
  # --------------------------------- else  ---------------------------------- #
  else { 
    print "... failed\n";
    return @rc; 
  }

  # *** WBEMCLI BUG WORKAROUND ***
  # Special case when wbemcli returns "not yet supported" and expecting "NOT_SUPPORTED" from cimom.
  # wbemcli does not currently support createIstance() for associations, and returns the error 
  # "Cmd Exception: create/modify instance with reference values not yet supported"
  # which should *not* cause the test to fail if "CIM_ERR_NOT_SUPPORTED" was expected anyway...
  if ( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/not yet supported/i && $rv=~/NOT_SUPPORTED/i) {
      $rc[0]=1;
      $rc[1]="ok - operation returned with $enum[1]";

      my @texec = times();
      $rc[2]=$texec[0]-$stexec[0];
      $rc[3]=$texec[1]-$stexec[1];
      $rc[4]=$texec[2]-$stexec[2];
      $rc[5]=$texec[3]-$stexec[3];

      print "... ok\n";
      return @rc;
    }
  }

  if ( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/${cimom::ERROR_PREFIX}/i && !($enum[1]=~/${cimom::ERROR_PREFIX}$rv/i) ) {
      $rc[0]=9;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - unexpected exception occured - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  if ( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/${cimom::ERROR_PREFIX}/i && ($enum[1]=~/${cimom::ERROR_PREFIX}$rv/i) ) {
      $rc[0]=1;
      $rc[1]="ok - operation returned with $rv";

      my @texec = times();
      $rc[2]=$texec[0]-$stexec[0];
      $rc[3]=$texec[1]-$stexec[1];
      $rc[4]=$texec[2]-$stexec[2];
      $rc[5]=$texec[3]-$stexec[3];

      print "... ok\n";
      return @rc;
    }
  }
  
  $rc[0]=8;
  $rc[1]="failed - $rv expected - check behavior of provider by hand !";
  print "... failed\n";
  return @rc;
}

#******************************************************************************#


# end of module instance.pm
