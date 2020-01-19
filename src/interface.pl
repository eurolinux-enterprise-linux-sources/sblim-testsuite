#!/usr/bin/perl

#
# interface.pl
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
# This perl script acts as entry point to test the implemented
# interface types of a certain class.
#

use strict;
use warnings;

use cimom;


# use module with Instance Interface Support
use instance;
# use module with Associator Interface Support
use associator;

#******************************************************************************#
#                             Input Parameter                                  #

my $i=0;
my $CLASS;
my $CHECK_INPUTPARAMS;
my $VERBOSE;

while( defined($ARGV[$i])) {

  # if an input parameter is sepcified with -assocParams, then execute the
  # test to valaidate the input parameter role, resultRole and resultClass
  if($ARGV[$i]=~ /-assocParams/) { $CHECK_INPUTPARAMS=1; }

  # create verbose output
  elsif($ARGV[$i]=~ /-v/) { $VERBOSE=1; }

  # initialize class name
  elsif($ARGV[$i]=~ /-className/) { $i++; $CLASS=$ARGV[$i]; }

  # print help
  elsif($ARGV[$i]=~/-h/ || $ARGV[$i]=~/--help/ ) { 
    print "test the interfaces of a provider\n";
    print "\n";
    print "   -className <class name>: specifies the name of the class to test and\n";
    print "                            the file name in the cim sub directory\n";
    print "   -assocParams           : if the tested class is an association, it is\n";
    print "                            possible to test the algorithm, which validates\n";
    print "                            the input parameter role, resultRole and resultClass\n";
    print "   -v                     : generate verbose output\n";
    print "   -h, --help             : print this message\n";
    print "\n";
    exit 0;
  }

  else { print "interface.pl --- unknown argument : $ARGV[$i]\n"; exit 0; }

  $i++;
}

if(!defined $CLASS) {
  print "interface.pl --- please specify the class name you want to test\n";
  exit 0;
}

#                                                                              #
#******************************************************************************#

my @INTERFACE_TYPE = (# Instance Interface
		      "Instance",
		      # Associator Interface
		      "Association",
		      # Method Interface
		      "Method",
		      # Property Interface
		      "Property",
		      # Indication Interface
		      "Indication");

my @INTERFACE_OP   = (# Instance Interface
		      "enumInstances","enumInstanceNames",
#		      "get","set",
		      "get","modify",
		      "create","delete",
		      "execQuery",
		      # Associator Interface
		      "associators", "associatorNames",
		      "references","referenceNames",
		      # Method Interface
		      "invokeMethod",
		      # Property Interface
		      "getProperty","setProperty"
		      # Indication Interface
		      );


#******************************************************************************#
#                             Global Variables                                 #

# --------------------------- Return Codes ------------------------------------#

my @rc  = ();            # return code of the single operations, e.g. enumerate()
my @crc = (0,0,0,0,0,0); # overall return code

# --------------------------- Test Operation ----------------------------------#

my $TEST_CONTENT;        # current interface type -> values from $INTERFACE_TYPE
my $TEST_OP;             # current test operation -> values from @INTERFACE_OP

# --------------------------- Input File --------------------------------------#

my $INPUT_PATH="cim";    # path to input files
my $INPUT_CIM;           # file handle to input file
my $line;                # read line from current input file
my $inst;                # objectPath of the current class
my $modifyInst;          # objectPath of the modified instance
my $volatile;            # set if class is volatile, e.g. processes

# if association is tested, the following four parameters holds the
# association specific property names (role) and values (class name)
my $sourceRole;
my $targetRole;
my @sourceClass;
my @targetClass;

# --------------------------- Report File -------------------------------------#

my $REPORT_FILE="stat/$CLASS.cim"; 
my $OLD_HDL;             # save file handle of STDOUT; necessary when report file is generated

#                                                                              #
#******************************************************************************#



#******************************************************************************#
#                                                                              #
#                   Test the different Provider Interfaces                     #
#                                                                              #
#******************************************************************************#

# open cim/$CLASS.cim for reading
if( !open(INPUT_CIM, "$INPUT_PATH/$CLASS.cim")) {
  print "$CLASS - interface test - can not open CIM Input File\n\n\n";
  exit 0;
}
unlink($REPORT_FILE);

while ($line = <INPUT_CIM>) {
  if( $line =~ /\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*/ ) {
    $line = <INPUT_CIM>;

    if( $line =~ /^class/i ) {
      # third line in cim/$CLASS.cim is a sample instance !
      $line = <INPUT_CIM>;	
      chomp($line);
      if( $line =~ /objectPath : /i ) {
	$line =~ s/objectPath : //;
	$inst = $line;
      }
      $line = <INPUT_CIM>;	
      chomp($line);
      if( $line =~ /modifyInst : /i ) {
	$line =~ s/modifyInst : //;
	$modifyInst = $line;
	$line = <INPUT_CIM>;
	$volatile=1 if($line =~ /volatile/i);
      }
      # test if class is volatile
      elsif($line =~ /volatile/i) { $volatile=1; }
    } # end of Instance specific Input

    if( $line =~ /^association/i ) {
      # third line in cim/$CLASS.cim is a sample instance !
      $line = <INPUT_CIM>;	
      chomp($line);
      if( $line =~ /objectPath : /i ) {
	$line =~ s/objectPath : //;
	$inst = $line;
      }
      $line = <INPUT_CIM>;	
      chomp($line);
      if( $line =~ /modifyInst : /i ) {
	$line =~ s/modifyInst : //;
	$modifyInst = $line;
      }
      my $read;
      foreach my $i (1 .. 4) {
        $read = <INPUT_CIM>;
	chomp($read);
	# defines the Role of the left Reference
	if( $read =~ /sourceRole : / ) {
	  $sourceRole = $read;
	  $sourceRole =~ s/sourceRole : //;
	}
	if( $read =~ /targetRole : / ) {
	  $targetRole = $read;
	  $targetRole =~ s/targetRole : //;
	}
	if( $read =~ /sourceClass : / ) {
	  $read =~ s/sourceClass : //;
	  @sourceClass = split(' ',$read);
	}
	if( $read =~ /targetClass : / ) {
	  $read =~ s/targetClass : //;
	  @targetClass = split(' ',$read);
        }
      }
      # test if class is volatile
      $line = <INPUT_CIM>;
      $volatile=1 if($line =~ /volatile/i);

      if( ! defined $sourceClass[0] && ! defined $targetClass[0]) { 
        print "class name of left or right reference not specified in Input file $CLASS.cim";
	exit;
      }
    } # end of Associator specific Input
  } # end of common Input

  if( $line =~ /-----------------------------------------------------------/ ) {
    $line = <INPUT_CIM>;
    chomp($line);
    my $next = "";
    if ( ! eof INPUT_CIM ) {
      $next = <INPUT_CIM>;
      chomp($next);
    }

    # --------------------------- Instance Interface ---------------------------
    if( $line =~ /^Instance/i ) {

      # define the current content of the test : Instance Interface
      $TEST_CONTENT=$INTERFACE_TYPE[0];

      # enumerate
      if( $line =~ /enumInstanceNames$|enumInstances$/i ) {
	$TEST_OP=$INTERFACE_OP[0] if( $line =~ /enumInstances$/i );
	$TEST_OP=$INTERFACE_OP[1] if( $line =~ /enumInstanceNames$/i );
	if($next=~/Expected Exception : /) { 
	  $next=~s/Expected Exception : //;
	  @rc=&check_returnedException($CLASS,$TEST_OP,$next);
	}
	else { @rc = &enumerate($CLASS,$TEST_OP); }
      }

      # get
      if( $line =~ /get$/i ) {
	$TEST_OP=$INTERFACE_OP[2];
	if($next=~/Expected Exception : /) { 
	  $next=~s/Expected Exception : //;
	  @rc=&check_returnedException($CLASS,$TEST_OP,$next,$inst);
	}
	else { @rc = &get($CLASS,$volatile); }
      }

      # modify (old name: set)
      if( $line =~ /modify$|set$/i ) {
	if( !(defined $modifyInst) ) { 
	    print "failed modify() --- no sample Instance specified in cim/$CLASS.cim - skipped test\n\n"; 
	    # reset rc
	    @rc = (6,"failed modify() --- no sample Instance specified in cim/$CLASS.cim - skipped test");
	    #exit 0; 
	}
	else {
	    $TEST_OP=$INTERFACE_OP[3];
	    if($next=~/Expected Exception : /) { 
		$next=~s/Expected Exception : //;
		@rc=&check_returnedException($CLASS,$TEST_OP,$next,$modifyInst);
	    }
	    else { @rc = &modify($CLASS,$inst,$modifyInst); }
	}
      }

      # create
      if( $line =~ /create$/i ) {
	if( !(defined $inst) ) { print "failed create() --- no sample Instance specified in cim/$CLASS.cim - third line\n\n"; exit 0; }
	if( !($inst =~ /$CLASS\./) ) { print "failed create() --- no sample Instance specified in cim/$CLASS.cim - third line\n\n"; exit 0; }
	$TEST_OP=$INTERFACE_OP[4];
	if($next=~/Expected Exception : /) { 
	  $next=~s/Expected Exception : //;
	  @rc=&check_returnedException($CLASS,$TEST_OP,$next,$inst);
	}
	else { @rc = &create($CLASS,$inst); }
      }

      # delete
      if( $line =~ /delete$/i ) {
	if( !(defined $inst) ) { print "failed create() --- no sample Instance specified in cim/$CLASS.cim - third line\n\n"; exit 0; }
	if( !($inst =~ /$CLASS\./) ) { print "failed delete()--- no sample Instance specified in cim/$CLASS.cim - third line\n\n"; exit 0; }
	$TEST_OP=$INTERFACE_OP[5];
	if($next=~/Expected Exception : /) { 
	  $next=~s/Expected Exception : //;
	  @rc=&check_returnedException($CLASS,$TEST_OP,$next,$inst);
	}
	else { @rc = &delete($CLASS,$inst); }
      }

# TODO +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      # execQuery
      if( $line =~ /execQuery$/i ) {
	$TEST_OP=$INTERFACE_OP[6];
	print "$CLASS --- $TEST_OP --- NOT SUPPORTED BY TEST SUITE\n";
	@rc = (0,"NOT_SUPPORTED");
      }
# end of TODO ++++++++++++++++++++++++++++++++++++++++++++++++++++++++

      $crc[2]=$crc[2]+$rc[2] if(defined $rc[2]); 
      $crc[3]=$crc[3]+$rc[3] if(defined $rc[3]); 
      $crc[4]=$crc[4]+$rc[4] if(defined $rc[4]); 
      $crc[5]=$crc[5]+$rc[5] if(defined $rc[5]);

      &intf_inst_write_report();
    }

    # --------------------------- Associator Interface ---------------------------
    if( $line =~ /^Association/i ) {

      # define the current content of the test : Associator Interface
      $TEST_CONTENT=$INTERFACE_TYPE[1];

      # associators
      if( $line =~ /associators$|associatorNames$/i ) {
	$TEST_OP=$INTERFACE_OP[7] if( $line =~ /associators$/i );
	$TEST_OP=$INTERFACE_OP[8] if( $line =~ /associatorNames$/i );
	if($next=~/Expected Exception : /) { 
	  $next=~s/Expected Exception : //;
	  @rc=&check_returnedException($CLASS,$TEST_OP,$next,$sourceClass[0]);
	}
	else { 
	  @rc = &associators($CLASS,$TEST_OP, 
			     $sourceClass[0], $targetClass[0], 
			     $sourceRole, $targetRole,
			     $volatile);
        }
      }

      # references
      if( $line =~ /references$|referenceNames$/i ) {
	$TEST_OP=$INTERFACE_OP[9] if( $line =~ /references$/i );
	$TEST_OP=$INTERFACE_OP[10] if( $line =~ /referenceNames$/i );
	if($next=~/Expected Exception : /) { 
	  $next=~s/Expected Exception : //;
	  @rc=&check_returnedException($CLASS,$TEST_OP,$next,$sourceClass[0]);
	}
	else { 
	  @rc = &references($CLASS,$TEST_OP, 
			    $sourceClass[0], $targetClass[0], 
			    $sourceRole, $targetRole,
			    $volatile);
        }
      }

      $crc[2]=$crc[2]+$rc[3] if ( defined $rc[3] ); 
      $crc[3]=$crc[3]+$rc[4] if ( defined $rc[4] ); 
      $crc[4]=$crc[4]+$rc[5] if ( defined $rc[5] ); 
      $crc[5]=$crc[5]+$rc[6] if ( defined $rc[6] );

      &intf_assoc_write_report();
    }

  }
}

if ( defined $CHECK_INPUTPARAMS ) {
  if ( defined $sourceClass[0] && defined $targetClass[0] && 
       defined $sourceRole     && defined $targetRole      ) {

    # test algorith which validates the input parameter 
    # role, resultRole and resultClass within an 
    # association provider

    my @list = (\@sourceClass,\@targetClass);
    
    &check_role_resultRole_resultClass_Params($CLASS,
					      $sourceRole,$targetRole,
					      @list);
  }
}


&intf_close_write_report();

print "-----------------------------------------------------------------------------------\n";
print "$CLASS --- Number of Tests where Status ok     : $crc[0]\n" if (defined $crc[0]);
print "$CLASS --- Number of Tests where Status failed : $crc[1]\n" if (defined $crc[1]);
print "\n\n";

close(INPUT_CIM);

if (defined $crc[1]) {
  if($crc[1]!~0) { exit(-1); }
}

exit(0);


#******************************************************************************#
#                                                                              #
#                           Report Definitions                                 #
#                                                                              #
#******************************************************************************#



#******************************************************************************#
#                                                                              #
# Definition of Report File for Instance Interface Tests                       #
#                                                                              #
#******************************************************************************#

sub intf_inst_write_report {
  # open Report File for this Class; if necessary one is created
  $^="INTERFACE_INST_TOP";
  $~="INTERFACE_INST";
  open(INTERFACE_INST,">> $REPORT_FILE") or die "can not create Report File for ".$CLASS;
  $OLD_HDL = select(INTERFACE_INST);
  write;
  close(INTERFACE_INST);
  select($OLD_HDL);

  $crc[0]++ if( $rc[0] == 1 );              # ok
  $crc[1]++ if( ( $rc[0] != 1  ) && 
		( $rc[0] != 0  ) && 
		( $rc[0] != 14 ));          # failed
}

#******************************************************************************#
# Header
#

format INTERFACE_INST_TOP =
********************************************************************************
class : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
localtime()."\n";

.

#******************************************************************************#
# Line
#

format INTERFACE_INST =
--------------------------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$TEST_CONTENT, $TEST_OP
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])
RC     : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[0] if (defined $rc[0])
last executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[7] if(defined $rc[7] && defined($VERBOSE));
Number of Returned Instances : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[6] if(defined $rc[6]);
user time       : @<<<<<<<<<<    child user time   : @<<<<<<<<<<    ut : @>>>>>>
$rc[2], $rc[4], $rc[2]+$rc[4] if (defined $rc[2])
system time     : @<<<<<<<<<<    child system time : @<<<<<<<<<<    st : @>>>>>>
$rc[3], $rc[5], $rc[3]+$rc[5] if (defined $rc[3])

.

#******************************************************************************#



#******************************************************************************#
#                                                                              #
# Definition of Report File for Associator Interface Tests                     #
#                                                                              #
#******************************************************************************#

sub intf_assoc_write_report {
  # open Report File for this Class; if necessary one is created
  $^="INTERFACE_ASSOC_TOP";
  $~="INTERFACE_ASSOC";
  open(INTERFACE_ASSOC,">> $REPORT_FILE") or die "can not create Report File for ".$CLASS;
  $OLD_HDL = select(INTERFACE_ASSOC);
  write;
  close(INTERFACE_ASSOC);
  select($OLD_HDL);

  $crc[0]++ if($rc[0] == 1.1);    # ok
  $crc[1]++ if($rc[0] != 1.1);    # failed
}

#******************************************************************************#
# Header
#

format INTERFACE_ASSOC_TOP =
********************************************************************************
association : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
localtime()."\n";

.

#******************************************************************************#
# Line
#

format INTERFACE_ASSOC =
--------------------------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$TEST_CONTENT, $TEST_OP
RC     : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[0] if (defined $rc[0])
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])
last executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[9] if(defined $rc[9] && defined($VERBOSE));
Number of Returned Instances : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[7] if(defined $rc[7]);
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[2] if (defined $rc[2])
last executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[10] if(defined $rc[10] && defined($VERBOSE));
Number of Returned Instances : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[8] if(defined $rc[8]);
user time       : @<<<<<<<<<<    child user time   : @<<<<<<<<<<    ut : @>>>>>>
$rc[3], $rc[5], $rc[3]+$rc[5] if (defined $rc[3])
system time     : @<<<<<<<<<<    child system time : @<<<<<<<<<<    st : @>>>>>>
$rc[4], $rc[6], $rc[4]+$rc[6] if (defined $rc[4])

.

#******************************************************************************#



#******************************************************************************#
#                                                                              #
# Definition of Report File for overall test status                            #
#                                                                              #
#******************************************************************************#

sub intf_close_write_report {
  # open Report File for this Class; if necessary one is created
  $^="INTERFACE_CLOSE_TOP";
  $~="INTERFACE_CLOSE";
  open(INTERFACE_CLOSE,">> $REPORT_FILE") or die "can not create Report File for ".$CLASS;
  $OLD_HDL = select(INTERFACE_CLOSE);
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
#                            end of interface.pl                               #
#******************************************************************************#
