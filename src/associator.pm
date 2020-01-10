#!/usr/bin/perl
#
# associator.pm
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
# interface of an Associator Provider.
#

package associator;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(associators references check_role_resultRole_resultClass_Params);

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
# 2  ... Exception occurred
# 3  ... returned Instances was not of the class type, that was asked for in
#        parameter ${class} -> Provider failure ?
#


#******************************************************************************#
# call associators or associatorNames of a certain class
#
# @rc = ( $ReturnCode,
#         $ReturnCodeDescription-SourceClass,
#         $ReturnCodeDescription-TargetClass,
#         $UserTime, $SystemTime, 
#         $ChildUserTime, $ChildSystemTime, 
#         $NumberOfInstances-SourceClass, 
#         $NumberOfInstances-TargetClass )
#

sub associators {
  my ($class, $op, $sourceClass, $targetClass, $sourceRole, $targetRole, $volatile) = @_;
  my @stexec = times();
  print $class." --- $op() started\n";
  my @rc = (0,"");

  # sourceClass is starting point (Input) -> check returning of targetClass values
  my @lrc = exec_assoc($class, $op, $sourceClass, $targetClass, $volatile);
  # targetClass is starting point (Input) -> check returning of sourceClass values
  my @rrc = exec_assoc($class, $op, $targetClass, $sourceClass, $volatile);
  
  $rc[0]="$lrc[0].$rrc[0]";
  $rc[1]="$sourceClass to $targetClass : $lrc[1]";
  $rc[2]="$targetClass to $sourceClass : $rrc[1]";
  $rc[9]="$lrc[3]";
  $rc[10]="$rrc[3]";

  if( ($lrc[0]==1) && ($rrc[0]==1) ) {
    my @texec = times();
    $rc[3]=$texec[0]-$stexec[0];
    $rc[4]=$texec[1]-$stexec[1];
    $rc[5]=$texec[2]-$stexec[2];
    $rc[6]=$texec[3]-$stexec[3];
    $rc[7]=$lrc[2];
    $rc[8]=$rrc[2];
  }

  return @rc;
}

#******************************************************************************#

sub exec_assoc {
  my ($class, $op, $ref, $target, $volatile) = @_;

  print $class." --- $op() - $ref to $target - started ";
  my $count = 0;
  my @rc = (0,"");
  my @assoc;
  $|=1;

#  my @enum = `2>&1 wbemein ${cimom::HOST}${ref}`;
  my @enum = wbem_cli("wbemein", "${cimom::WBEMFLAG} ${cimom::HOST}${ref}");
  $rc[3]="wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${ref}";
  if ( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/${cimom::ERROR_PREFIX}/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration $ref - exception occurred - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  if( !defined $enum[0] ) {
      $rc[3]="enumeration - no instances for source class $ref found";
  }

  foreach my $elem (@enum) {
    print ".";
    $count=0;
    chomp($elem);
#    if    ( $op =~ /associatorNames/) { @assoc = `2>&1 wbemain -ac $class '${cimom::PROTOCOL}${elem}'`; 
    if    ( $op =~ /associatorNames/) { @assoc = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class -arc $target '${cimom::PROTOCOL}${elem}'"); 
					$rc[3]="wbemain ${cimom::WBEMFLAG} -ac $class -arc $target'${cimom::PROTOCOL}${elem}'";
				      }
#    elsif ( $op =~ /associators/ )    { @assoc = `2>&1 wbemai -ac $class '${cimom::PROTOCOL}${elem}'`; 
    elsif ( $op =~ /associators/ )    { @assoc = wbem_cli("wbemai", "${cimom::WBEMFLAG} -ac $class -arc $target '${cimom::PROTOCOL}${elem}'"); 
                                        $rc[3]="wbemai -ac $class -arc $target ${cimom::WBEMFLAG} '${cimom::PROTOCOL}${elem}'";
				      }
    else { 
      print "... failed\n";
      return @rc; 
    }
    
   if( defined $assoc[0] && defined $assoc[1]) {
      if ( $assoc[0]=~/\*/ && $assoc[1]=~/${cimom::ERROR_PREFIX}/i) {
	chomp($assoc[1]);
	$assoc[1] =~ s/\* //;
        if( defined $volatile ) {
          $rc[0]=1;
	  $rc[1]="warning - $op - volatile class type returned with exception - $assoc[1]";
	  print "... warning\n";
        }
	else {
          $rc[0]=12;
	  $rc[1]="failed - $op - exception occurred - $assoc[1]";
	  print "... failed\n";
	}
	return @rc;
      }
    }
    foreach my $assoc (@assoc) {
      print ".";
      if (!($assoc=~/$target\./i) && !($target=~/CIM_/i) ) {
	$rc[0]=13;
	$rc[1]="failed - returned instance(s) is/are not of class type $target";
	print "... failed\n";
	return @rc;
      }
      $count++;
    }

    if( defined $rc[2] ) {
	$rc[2]=$rc[2]." ".$count;
    }
    else { $rc[2]=$count; }
  }

  $rc[0]=1;
  $rc[1]="ok";
  print "... ok\n";
  return @rc;
}


#******************************************************************************#
# references
#
# call references or referenceNames of a certain class
#
# @rc = ( $ReturnCode,
#         $ReturnCodeDescription-SourceClass, $ReturnCodeDescription-TargetClass,
#         $UserTime, $SystemTime, 
#         $ChildUserTime, $ChildSystemTime, 
#         $NumberOfInstances-SourceClass, $NumberOfInstances-TargetClass )
#


sub references {
  my ($class, $op, $sourceClass, $targetClass, $sourceRole, $targetRole, $volatile) = @_;
  my @stexec = times();
  print "$class --- $op() started\n";
  my @rc = (0,"");

  # sourceClass is starting point (Input) -> check returning of targetClass values
  my @lrc = exec_ref($class, $op, $sourceClass, $targetClass, $volatile);
  # targetClass is starting point (Input) -> check returning of sourceClass values
  my @rrc = exec_ref($class, $op, $targetClass, $sourceClass, $volatile);

  $rc[0]="$lrc[0].$rrc[0]";
  $rc[1]="$sourceClass to $targetClass : $lrc[1]";
  $rc[2]="$targetClass to $sourceClass : $rrc[1]";
  $rc[9]="$lrc[3]";
  $rc[10]="$rrc[3]";

  if( ($lrc[0]==1) && ($rrc[0]==1) ) {
    my @texec = times();
    $rc[3]=$texec[0]-$stexec[0];
    $rc[4]=$texec[1]-$stexec[1];
    $rc[5]=$texec[2]-$stexec[2];
    $rc[6]=$texec[3]-$stexec[3];
    $rc[7]=$lrc[2];
    $rc[8]=$rrc[2];
  }

  return @rc;
}

#******************************************************************************#

sub exec_ref {
  my ($class, $op, $ref, $target, $volatile) = @_;
  print "$class --- $op() - $ref to $target - started ";
  my $count = 0;
  my @rc = (0,"");
  my @refer;
  $|=1;

#  my @enum = `2>&1 wbemein ${cimom::HOST}${ref}`;
  my @enum = wbem_cli("wbemein", "${cimom::WBEMFLAG} ${cimom::HOST}${ref}");
  $rc[3]="wbemein ${cimom::WBEMFLAG} ${cimom::HOST}${ref}";
  if ( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/${cimom::ERROR_PREFIX}/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration $ref - exception occurred - $enum[1]";
      print "... failed\n";
      return @rc;
    }
  }

  if( !defined $enum[0] ) {
      $rc[3]="enumeration - no instances for source class $ref found";
  }

  foreach my $elem (@enum) {
    print ".";
    $count=0;

    chomp($elem);
#    if    ( $op =~ /referenceNames/) { @refer = `2>&1 wbemrin -arc $class '${cimom::PROTOCOL}${elem}'`; 
    if    ( $op =~ /referenceNames/) { @refer = wbem_cli("wbemrin", "${cimom::WBEMFLAG} -arc $class '${cimom::PROTOCOL}${elem}'"); 
				       $rc[3] = "wbemrin ${cimom::WBEMFLAG} -arc $class '${cimom::PROTOCOL}${elem}'";
				     }
#    elsif ( $op =~ /references/ )    { @refer = `2>&1 wbemri -arc $class '${cimom::PROTOCOL}${elem}'`; 
    elsif ( $op =~ /references/ )    { @refer = wbem_cli("wbemri", "${cimom::WBEMFLAG} -arc $class '${cimom::PROTOCOL}${elem}'"); 
				       $rc[3] = "wbemri ${cimom::WBEMFLAG} -arc $class '${cimom::PROTOCOL}${elem}'";
				     }
    else { 
      print "... failed\n";
      return @rc; 
    }

    if( defined $refer[0] && defined $refer[1]) {
      if ( $refer[0]=~/\*/ && $refer[1]=~/${cimom::ERROR_PREFIX}/i) {
	chomp($refer[1]);
	$refer[1] =~ s/\* //;
	if( ! defined $volatile ) {
	  $rc[0]=12;
	  $rc[1]="failed - $op - exception occurred - $refer[1]";
	  print "... failed\n";
        } 
	else {
	  $rc[0]=1;
	  $rc[1]="warning - $op - volatile class type returned with exception - $refer[1]";
	  print "... warning\n";
	}
	return @rc;
      }
    }

    foreach my $refer (@refer) {
      print ".";

      if ( !($refer=~/$class\./i) ) {
	$rc[0]=13;
	$rc[1]="failed - returned instance(s) is/are not of class type $class";
	print "... failed\n";
	return @rc;
      }
      $count++;
    }

    if( defined $rc[2] ) {
	$rc[2]=$rc[2]." ".$count;
    }
    else { $rc[2]=$count; }
  }

  $rc[0]=1;
  $rc[1]="ok";
  print "... ok\n";
  return @rc;
}

#******************************************************************************#



#******************************************************************************#
#                                                                              #
# test algorithm, which handles the validation of the input parameters :       #
# - role                                in referenceNames()                    #
# - role, resultRole and resultClass    in associatorNames()                   #
#                                                                              #
#******************************************************************************#

my $TEST_CONTENT;
my $TEST_SOURCECLASS = "";
my $TEST_TARGETCLASS = "";
my $TEST_OP;
my $CLASS;

my @rc  = (0,"","",0,"","");
my @crc = (0,0);

sub check_role_resultRole_resultClass_Params {
  my ($class, $role, $resultRole, @classNames) = @_;
  print "\n$class --- test algorithm to validate input params started\n";
  $CLASS = $class;
  my $p=0;
  my $q=1;
  my $i=0;
  my $j=0;

  my @args = ("rm","stat/params_$CLASS.stat");
  system(@args) if( -e "stat/params_$CLASS.stat");

  my @stexec = times();

  for ( 0 .. 1 ) {
    # while sourceClass with each targetClass ( $p=0 $q=1 ) and
    # while targetClass with each sourceClass ( $p=1 $q=0 )
    while ( defined $classNames[$p]->[$i] ) {
      if ($classNames[$p]->[$i] =~ /CIM_/i ) {
	# warning
	print "$class --- sourceClass is $classNames[$p]->[$i] - a CIM class as source is not tested\n"
      }
      else {
        $TEST_SOURCECLASS = $classNames[$p]->[$i];
	if ( $p == 0 ) {
	  &check_inputParams($class, 
			     $role, $resultRole,
			     $classNames[$p]->[$i],$classNames[$q]);
        }
	elsif ( $p == 1 ) {
	  &check_inputParams($class, 
			     $resultRole, $role, 
			     $classNames[$p]->[$i],$classNames[$q]);
        }
      }      
      $i++;
    }
    $i=0; $p=1; $q=0;
  }

  my @texec = times();
  $crc[2]=$texec[0]-$stexec[0];
  $crc[3]=$texec[1]-$stexec[1];
  $crc[4]=$texec[2]-$stexec[2];
  $crc[5]=$texec[3]-$stexec[3];

  &intf_close_write_report();
}

sub check_inputParams {
  my ($class, $role, $resultRole, $sourceClass, @targetClass) = @_;
  print "$class --- $sourceClass to $targetClass[0]->[0] (and childs) ";
  my @refer = (); 
  my @assoc = ();
  my $i=0;

  # enumerate instances of the sourceClass and take 
  # each object path entry as reference for the 
  # referenceNames and associatorNames calls
#  my @enum = `2>&1 wbemein ${cimom::HOST}${sourceClass}`;
  my @enum = wbem_cli("wbemein", "${cimom::WBEMFLAG} ${cimom::HOST}${sourceClass}");

  if ( defined $enum[0] && defined $enum[1] ) {
    if ( $enum[0]=~/\*/ && $enum[1]=~/${cimom::ERROR_PREFIX}/i) {
      $rc[0]=2;
      chomp($enum[1]);
      $enum[1] =~ s/\* //;
      $rc[1]="failed - enumeration $sourceClass - exception occurred - $enum[1]";
      $TEST_CONTENT = $sourceClass;
      $TEST_OP = "enumInstanceNames";
      $crc[1]++;
      &intf_assoc_checkParams_write_report();
      print "... failed\n";
      return;
    }
  }

  foreach my $elem (@enum) {
    print ".";
    chomp($elem);

    $TEST_SOURCECLASS = $elem;

    # check resultClass parameter
    my $retc = &check_resultClass($class, $elem, $sourceClass, @targetClass);
    
    if ( $retc == 1 ) { 

      # check role parameter
      &check_role_resultRole($class, $elem, 1,
			     $role, $resultRole, $sourceClass, @targetClass);

      # check resultRole parameter
      &check_role_resultRole($class, $elem, 2,
			     $role, $resultRole, $sourceClass, @targetClass);
    }
    elsif ( $retc == -1 ) {
      print "\n$class --- test of role and resultRole parameter not executed - caused by failed test of resultClass\n"; 
      exit 0; 
    }

  }

  print "... finished\n";
}


#-----------------------------------------------------------------------#
#   op : 1 ... check role parameter
#        2 ... check resultRole parameter
#-----------------------------------------------------------------------#

sub check_role_resultRole {
  my ($class, $elem, $op,
      $role, $resultRole, $sourceClass, @targetClass) = @_;
  my $i=0;
  my $count=0;
  my @refer = ();
  my @assoc = ();

  #---------------------------------------------------------------------#

  if ( $op == 1 ) { 

    $TEST_OP = "referenceNames";
    $TEST_TARGETCLASS = $targetClass[0]->[0];
    $i=1;
    while ( defined $targetClass[0]->[$i] ) {
      $TEST_TARGETCLASS = $TEST_TARGETCLASS." || ".$targetClass[0]->[$i];
      $i++;
    }
    $i=0;
    @rc = (0,"","role is set to $role",0,"","role is set to $resultRole",0);

    #-------------------------------------------------------------------#

#    @refer = `2>&1 wbemrin -arc $class -ar $role '${cimom::PROTOCOL}${elem}'`;
    @refer = wbem_cli("wbemrin", "${cimom::WBEMFLAG} -arc $class -ar $role '${cimom::PROTOCOL}${elem}'");
    $rc[8] = "wbemrin ${cimom::WBEMFLAG} -arc $class -ar $role '${cimom::PROTOCOL}${elem}'";

    if ( defined $refer[0] && defined $refer[1] ) {
      if ( $refer[0]=~/\*/ && $refer[1]=~/${cimom::ERROR_PREFIX}/i) {
	$rc[0]=12;
	chomp($refer[1]);
	$refer[1] =~ s/\* //;
	$rc[1]="failed - exception occurred - $refer[1]";
	print "... failed ";
      }
    }

    if ( $rc[0]!=12 ) {
      foreach my $refer (@refer) {
	print ".";
	if ( !($refer=~/$role\=$sourceClass\./i) ) {
	  $rc[0]=13;
	  $rc[1]="failed - role parameter seems to be ignored (1)";
	  print "... failed ";
	  goto report_1;
        }  
	$count++;    
      }
      $rc[0]=1;
      $rc[1]="ok";
      $rc[6]=$count;
    }

  report_1:
    $crc[0]++ if ( $rc[0] == 1 );
    $crc[1]++ if ( $rc[0] != 1 ) ;

    #-------------------------------------------------------------------#
    
#    @refer = `2>&1 wbemrin -arc $class -ar $resultRole '${cimom::PROTOCOL}${elem}'`;
    @refer = wbem_cli("wbemrin", "${cimom::WBEMFLAG} -arc $class -ar $resultRole '${cimom::PROTOCOL}${elem}'");
    $rc[9] = "wbemrin ${cimom::WBEMFLAG} -arc $class -ar $resultRole '${cimom::PROTOCOL}${elem}'";

    if(defined $refer[0]) {
      $rc[3]=14;
      $rc[4]="failed - role parameter seems to be ignored (2)";
      print "... failed ";
    }
    else { $rc[3]=1; $rc[4]="ok - no instance(s) returned";}

    $crc[0]++ if ( $rc[3] == 1 );
    $crc[1]++ if ( $rc[3] != 1 ) ;
    
    &intf_assoc_checkParams_write_report();

  } # end of referenceNames()

  #---------------------------------------------------------------------#

  $TEST_OP = "associatorNames";

  #---------------------------------------------------------------------#

  while ( defined $targetClass[0]->[$i] ) {

    @rc = (0,"","role is set to $role ... resultClass is set to $targetClass[0]->[$i]",
	   0,"","role is set to $resultRole ... resultClass is set to $targetClass[0]->[$i]",0)
      if ( $op == 1 );  
  
    @rc = (0,"","resultRole is set to $resultRole ... resultClass is set to $targetClass[0]->[$i]",
	   0,"","resultRole is set to $role ... resultClass is set to $targetClass[0]->[$i]",0)
      if ( $op == 2 );

    $TEST_TARGETCLASS = $targetClass[0]->[$i];

    if ( $op == 1 ) {
#      @assoc = `2>&1 wbemain -ac $class -ar $role -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'`;
      @assoc = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class -ar $role -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'");
      $rc[8] = "wbemain ${cimom::WBEMFLAG} -ac $class -ar $role -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'";
   }
    if ( $op == 2 ) {
#      @assoc = `2>&1 wbemain -ac $class -arr $resultRole -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'`;
      @assoc = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class -arr $resultRole -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'");
      $rc[8] = "wbemain ${cimom::WBEMFLAG} -ac $class -arr $resultRole -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'";
    }

    $count=0;

    if ( defined $assoc[0] && defined $assoc[1] ) {
      if ( $assoc[0]=~/\*/ && $assoc[1]=~/${cimom::ERROR_PREFIX}/i) {
	$rc[0]=12;
	chomp($assoc[1]);
	$assoc[1] =~ s/\* //;
	$rc[1]="failed - exception occurred - $assoc[1]";
	print "... failed ";
      }
    }

    if ( $rc[0]!=12 ) {
      foreach my $assoc (@assoc) {
	print ".";
	if ( $targetClass[0]->[$i] =~ /CIM_/i ) {
	  my $j=1;
	  my $found=0;
	  while (defined $targetClass[0]->[$j]) {
	    $found=1 if ( $assoc =~ /$targetClass[0]->[$j]\./i );
	    $j++;
	  }
	  $rc[0]=13 if( $found == 0 );
	}
	elsif ( !($assoc=~/$targetClass[0]->[$i]\./i) ) {
	  $rc[0]=13;
	}
	if ( $rc[0]==13 ) {
	  if ( $op == 1 ) {
	    $rc[1]="failed - role parameter seems to be ignored (1)";
	    print "... failed ";
	  }
	  elsif ( $op == 2 ) {
	    $rc[0]=15;
	    $rc[1]="failed - resultRole parameter seems to be ignored (1)";
	    print "... failed ";
	  }
	  goto report_2;
	}
	$count++;
      }
      $rc[0]=1;
      $rc[1]="ok";
      $rc[6]=$count;
    }
 
  report_2:
    $crc[0]++ if ( $rc[0] == 1 ) ;
    $crc[1]++ if ( $rc[0] != 1 ) ;
    
    #---------------------------------------------------------------------#

    if ( $op == 1 ) {
#      @assoc = `2>&1 wbemain -ac $class -ar $resultRole -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'`;
      @assoc = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class -ar $resultRole -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'");
      $rc[9] = "wbemain ${cimom::WBEMFLAG} -ac $class -ar $resultRole -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'";
    }

    if ( $op == 2 ) {
#      @assoc = `2>&1 wbemain -ac $class -arr $role -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'`;
      @assoc = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class -arr $role -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'");
      $rc[9] = "wbemain ${cimom::WBEMFLAG} -ac $class -arr $role -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'";
    }
      
    if(defined $assoc[0]) {
      if ( $op == 1 ) {
	$rc[3]=14;
	$rc[4]="failed - role parameter seems to be ignored (2)";
      }
      elsif ( $op == 2 ) {
	$rc[3]=16;
	$rc[4]="failed - resultRole parameter seems to be ignored (2)";
      }
      print "... failed ";
    }   
    else { $rc[3]=1; $rc[4]="ok - no instance(s) returned";}

    $crc[0]++ if ( $rc[3] == 1 );
    $crc[1]++ if ( $rc[3] != 1 ) ;

    &intf_assoc_checkParams_write_report();

    #---------------------------------------------------------------------#
    $i++;
  }

  return;
}


sub check_resultClass {
  my ($class, $elem, $sourceClass, @targetClass) = @_;
  my $i=0;
  my $count=0;
  my $failed=$crc[1];
  my @assoc = ();

  $TEST_OP = "associatorNames";

  while ( defined $targetClass[0]->[$i] ) {

    @rc = (0,"","resultClass is set to $targetClass[0]->[$i]",
	   0,"","resultClass is set to $sourceClass",0);  

    $TEST_TARGETCLASS = $targetClass[0]->[$i];

#    @assoc = `2>&1 wbemain -ac $class -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'`;
    @assoc = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'");
    $rc[8] = "wbemain ${cimom::WBEMFLAG} -ac $class -arc $targetClass[0]->[$i] '${cimom::PROTOCOL}${elem}'";

    $count=0;

    if ( defined $assoc[0] && defined $assoc[1] ) {
      if ( $assoc[0]=~/\*/ && $assoc[1]=~/${cimom::ERROR_PREFIX}/i) {
	$rc[0]=12;
	chomp($assoc[1]);
	$assoc[1] =~ s/\* //;
	$rc[1]="failed - exception occurred - $assoc[1]";
	print "... failed ";
      }
    }

    if ( $rc[0]!=12 ) {
      foreach my $assoc (@assoc) {
	print ".";
	if ( $targetClass[0]->[$i] =~ /CIM_/i ) {
	  my $j=1;
	  my $found=0;
	  while (defined $targetClass[0]->[$j]) {
	    $found=1 if ( $assoc =~ /$targetClass[0]->[$j]\./i );
	    $j++;
	  }
	  $rc[0]=17 if( $found == 0 );
	}
	elsif ( !($assoc=~/$targetClass[0]->[$i]\./i) ) {
	  $rc[0]=17;
	}
	if ( $rc[0]==17 ) {
	  $rc[1]="failed - resultClass parameter seems to be ignored (1)";
	  print "... failed ";
	  goto report_3;
        }
	$count++;
      }
      $rc[0]=1;
      $rc[1]="ok - but no instance(s) returned" if( $count == 0 );
      $rc[1]="ok" if( $count > 0 );
      $rc[6]=$count;
    }
 
  report_3:
    $crc[0]++ if ( $rc[0] == 1 ) ;
    $crc[1]++ if ( $rc[0] != 1 ) ;
    
    #---------------------------------------------------------------------#
    
#    @assoc = `2>&1 wbemain -ac $class -arc $sourceClass '${cimom::PROTOCOL}${elem}'`;
    @assoc = wbem_cli("wbemain", "${cimom::WBEMFLAG} -ac $class -arc $sourceClass '${cimom::PROTOCOL}${elem}'");
    $rc[9] = "wbemain ${cimom::WBEMFLAG} -ac $class -arc $sourceClass '${cimom::PROTOCOL}${elem}'";

    if(defined $assoc[0]) {
      $rc[3]=18;
      $rc[4]="failed - resultClass parameter seems to be ignored (2)";
      print "... failed ";
    }   
    else { $rc[3]=1; $rc[4]="ok - no instance(s) returned"; }

    $crc[0]++ if ( $rc[3] == 1 );
    $crc[1]++ if ( $rc[3] != 1 ) ;

    #---------------------------------------------------------------------#

    &intf_assoc_checkParams_write_report();
    $i++;
  }

  return -1 if ( $failed < $crc[1] );
  return 1;
}

#******************************************************************************#
#                                                                              #
# Definition of Report File for Associator Interface Tests                     #
#                                                                              #
#******************************************************************************#

sub intf_assoc_checkParams_write_report {
  # open Report File for this Class; if necessary one is created
  $^="INTERFACE_ASSOC_PARAMS_TOP";
  $~="INTERFACE_ASSOC_PARAMS";
  open(INTERFACE_ASSOC_PARAMS,">> stat/params_$CLASS.stat") 
      or die "can not create Params Report File for ".$CLASS;
  my $OLD_HDL = select(INTERFACE_ASSOC_PARAMS);
  write;
  close(INTERFACE_ASSOC_PARAMS);
  select($OLD_HDL);
}

#******************************************************************************#
# Header
#

format INTERFACE_ASSOC_PARAMS_TOP =
********************************************************************************
association : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS
test algorithm to validate the input parameters role, resultRole and resultClass
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
localtime()."\n";

.

#******************************************************************************#
# Line
#

format INTERFACE_ASSOC_PARAMS =
--------------------------------------------------------------------------------
                                        @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$TEST_OP

sourceClass   : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$TEST_SOURCECLASS
targetClass   : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$TEST_TARGETCLASS

test content  : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[2] if(defined($rc[2]));
executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[8] if(defined($rc[8]));
#Return Code  : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#$rc[0] if(defined($rc[0]));
Status        : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if(defined($rc[1]));
Number of Returned Instances : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[6] if(defined($rc[6]));

test content  : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[5] if(defined($rc[5]));
executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[9] if(defined($rc[9]));
#Return Code  : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#$rc[3] if(defined($rc[3]));
Status        : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[4] if(defined($rc[4]));

.


#******************************************************************************#
#                                                                              #
# Definition of Report File for overall test status                            #
#                                                                              #
#******************************************************************************#

sub intf_close_write_report {
  # open Report File for this Class; if necessary one is created
  $^="INTERFACE_CLOSE_TOP";
  $~="INTERFACE_CLOSE";
  open(INTERFACE_CLOSE,">> stat/params_$CLASS.stat") 
      or die "can not create Params Report File for ".$CLASS;
  my $OLD_HDL = select(INTERFACE_CLOSE);
  write;
  close(INTERFACE_CLOSE);
  select($OLD_HDL);
}

#******************************************************************************#
# Header
#

format INTERFACE_CLOSE_TOP =

--------------------------------------------------------------------------------
********************************************************************************
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS

.

#******************************************************************************#
# Line
#

format INTERFACE_CLOSE =
Number of Tests where Status ok     : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$crc[0] if (defined $crc[0])
Number of Tests where Status failed : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$crc[1] if (defined $crc[1])
user time       : @<<<<<<<<<<    child user time   : @<<<<<<<<<<    ut : @>>>>>>
$crc[2], $crc[4], $crc[2]+$crc[4] if (defined $crc[2])
system time     : @<<<<<<<<<<    child system time : @<<<<<<<<<<    st : @>>>>>>
$crc[3], $crc[5], $crc[3]+$crc[5] if (defined $crc[3])

.

#******************************************************************************#



#******************************************************************************#

# to return with true, when package is "required" by another shell script
1;

#******************************************************************************#


#******************************************************************************#
# end of module associator.pm
#******************************************************************************#
