#!/usr/bin/perl

#
# consistence.pl
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
# This perl script acts as entry point to test if the implemented
# provider logic reports consistent system data.
#

use strict;
use warnings;

use cimom;
use consistence;

#******************************************************************************#
#                             Input Parameter                                  #

my $i=0;
my $CLASS;
my $INPUT_PATH;
my $VERBOSE;

while( defined($ARGV[$i])) {

  # contains the platform specific path to the system files
  if($ARGV[$i]=~ /-path/) { $i++; $INPUT_PATH=$ARGV[$i]; }

  # create verbose output
  elsif($ARGV[$i]=~ /-v/) { $VERBOSE=1; }

  # initialize class name
  elsif($ARGV[$i]=~ /-className/) { $i++; $CLASS=$ARGV[$i]; }

  elsif($ARGV[$i]=~/-h/ || $ARGV[$i]=~/--help/ ) { 
    print "test the consistence between the implementation of a provider\n";
    print "and the system view onto the resource\n";
    print "\n";
    print "   -className <class name>: specifies the name of the class to test\n";
    print "                            and the file name in the system/<platform>\n";
    print "                            sub directory\n";
    print "   - path                 : contains the platform specific path to the\n";
    print "                            system files\n";
    print "   -v                     : generate verbose output\n";
    print "   -h, --help             : print this message\n";
    print "\n";
    exit 0;
  }

  else { print "consistence.pl --- unknown argument : $ARGV[$i]\n"; exit 0; }

  $i++;
}

if(!defined $CLASS) {
  print "consistence.pl --- please specify the class name you want to test\n";
  exit 0;
}

#                                                                              #
#******************************************************************************#

my @CONSISTENCE_TYPE = ( "Class Level", 
			 "Property Level", 
			 "Instance Level",
			 "Association Level");

my @TEST_TYPES = ( "less than", 
		   "equal", 
		   "greater than",
		   "grep",
		   "set",
		   "empty");
my $TEST_TYPE;

#******************************************************************************#
#                             Global Variables                                 #


# --------------------------- Return Codes ------------------------------------#

my @rc  = ();            # return code of the single operations, e.g. enumerate()
my @crc = (0,0,0,0,0,0); # overall return code

# --------------------------- Test Operation ----------------------------------#

my $TEST_CONTENT;        # current consistence test type -> values from $CONSISTENCE_TYPE
my $PROPERTY_NAME;
my $volatile;
my $sourceClass;
my $targetClass;

# --------------------------- Input File --------------------------------------#

my $INPUT_SYSTEM;        # file handle to input file
my $INPUT_INST;          # file handle to instance input file
my $INPUT_FILE;          # file handle to input files like $CLASS.keys
my $line;                # read line from current input file

# --------------------------- Report File -------------------------------------#

my $REPORT_FILE="stat/$CLASS.system"; 
my $OLD_HDL;             # save file handle of STDOUT; necesarry when report file is generated

#                                                                              #
#******************************************************************************#



#******************************************************************************#
#                                                                              #
#                  Test the data consistence of the provider                   #
#                                                                              #
#******************************************************************************#

# open system file for reading
if( !open(INPUT_SYSTEM, "$INPUT_PATH/$CLASS.system")) {
  print "$CLASS - consistence test - can not open System Input File\n\n\n"; 
  exit 0;
}
unlink("$REPORT_FILE");

$line = <INPUT_SYSTEM>;
# Class specific consistence test
if ( $line =~ /\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*/ ) {
  while ( $line = <INPUT_SYSTEM> ) {

    if( $line =~ /class :/i ) {
      $line = <INPUT_SYSTEM>;
      $volatile=1 if ($line =~ /volatile/i);

      while ( $line = <INPUT_SYSTEM> ) {
	@rc = (0,0);
	$TEST_TYPE="";
	chomp($line);

	if ( $line =~ /^$CLASS/i ) {
	  $line =~ s/$CLASS : //;
	  
	  if ( $line =~ /^-lt/i ) {
	    $line =~ s/-lt //i;
	    $TEST_TYPE=$TEST_TYPES[0];
	  }    
	  elsif ( $line =~ /^-eq/i ) {
	    $line =~ s/-eq //i;
	    $TEST_TYPE=$TEST_TYPES[1];
	  }     
	  elsif ( $line =~ /^-gt/i ) {
	    $line =~ s/-gt //i;
	    $TEST_TYPE=$TEST_TYPES[2];
	  }

	  if ( $line =~ /^-cmd/i ) {
	    $line =~ s/-cmd //i;
	    $line = qx/$line/;
	    chomp($line);
	    $line =~ s/ |\t//g;
	  }
	  @rc = &compareNumberOfInstances($CLASS,$TEST_TYPE,$line,$volatile);
	  &consistence_class_write_report();

	  if(defined($rc[2])) { last if($rc[2]==0); }

	  while(!($line =~ /-----------------------------------------------------------/)) 
	    { $line = <INPUT_SYSTEM>; }
	  $line = <INPUT_SYSTEM>;
	  chomp($line);
        }
	elsif ( $line =~ /^Instance Level/i ) { 
	  if ($line =~ /:/) {
	    $line =~ s/Instance Level : //;  
	    $INPUT_INST = $line;
	    chdir $INPUT_PATH;
	    $line = qx/\.\/$INPUT_INST/;
	    chdir "../..";
		      
	    $line = <INPUT_SYSTEM>;
	    chomp($line);
	    if ( $line =~ /^Property Order :/i ) {
	      $line =~ s/Property Order : //i;
	      @rc = &compareInstanceValues("$INPUT_PATH/$CLASS.instance",$CLASS,$line,$volatile);
	      &consistence_inst_write_report();
	      chdir $INPUT_PATH;
	      $line = qx/\.\/$INPUT_INST -rm/;
	      chdir "../..";
	    }
	    else { print "please define Property Order : <name> <name> ...\n"; }
	  }
	  else { 
	    $line = <INPUT_SYSTEM>;
	    print "please define Instance Level : <script>\n"; 
	  }
        }
	elsif ( $line =~ /^(.*?):/ ) {
	    $PROPERTY_NAME = $1;   
	    $line =~ s/$PROPERTY_NAME: //;
	    $PROPERTY_NAME =~ s/ |\t//g;
	    
	    if ( $line =~ /^-lt/i ) {
	      $line =~ s/-lt //i;
	      $TEST_TYPE=$TEST_TYPES[0];
	    }    
	    elsif ( $line =~ /^-eq/i ) {
	      $line =~ s/-eq //i;
	      $TEST_TYPE=$TEST_TYPES[1];
	    }     
	    elsif ( $line =~ /^-gt/i ) {
	      $line =~ s/-gt //i;
	      $TEST_TYPE=$TEST_TYPES[2];
	    }
	    elsif ( $line =~ /^-grep/i ) {
	      $line =~ s/-grep //i;
	      $TEST_TYPE=$TEST_TYPES[3];
	    }
	    elsif ( $line =~ /^-set/i ) {
	      $TEST_TYPE=$TEST_TYPES[4];
	    }    
	    elsif ( $line =~ /^-empty/i ) {
	      $TEST_TYPE=$TEST_TYPES[5];
	    }    
	  
	    if ( $line =~ /^-cmd/i ) {
	      $line =~ s/-cmd //i;
	      $line = qx/$line/;
	      chomp($line);
	      $line =~ s/\t//g;
	    }
	    elsif ( $line =~ /^-file/i ) {
	      $line =~ s/-file //i;
	      my $file;
	      if ( $line =~ /^(.*?)\[/ ) {
		$file = $1;
	      }   
		
	      my $linecount=0;
	      if ( $line =~ /^(.*?)\[(.*?)\]/ ) {
		$linecount = $2;
	      }
	      open(INPUT_FILE, "$INPUT_PATH/$file") or 
		  die "can not open System Input File $INPUT_PATH/$file for ".$CLASS;
	      my $i=0;
	      for ( $i .. $linecount ) {
		$line = <INPUT_FILE>;
	      }
	      chomp($line);
	    }
	    
	    @rc = &comparePropertyValue($CLASS,$TEST_TYPE,$PROPERTY_NAME,$line,$volatile);
	    &consistence_property_write_report();
	}
      }
    }
    elsif( $line =~ /association :/i ) {
      $line = <INPUT_SYSTEM>;
      $volatile=1 if ($line =~ /volatile/i);
      while ( $line = <INPUT_SYSTEM> ) {
	if ( $line =~ /--------------------------------------------------------/ ) {
	  while ( $line = <INPUT_SYSTEM> ) {
	    @rc = (0,0);

	    if ( $line =~ /^(.*?):/ ) {
	      chomp($line);
	      $sourceClass = $1;
	      $sourceClass =~ s/\s//g;
	      $line =~ s/$sourceClass : //;

	      if( $line =~ /^-target/i ) {
	        $line =~ s/-target //i;
		if ( $line =~ /^(.*?)\s/ ) {
		  $targetClass = $1; 
		  $targetClass =~ s/\s//g;
		  $line =~ s/$targetClass //;
		}
	      }
      
	      if ( $line =~ /^-lt/i ) {
	        $line =~ s/-lt //i;
		$TEST_TYPE=$TEST_TYPES[0];
	      }    
	      elsif ( $line =~ /^-eq/i ) {
		$line =~ s/-eq //i;
		$TEST_TYPE=$TEST_TYPES[1];
	      }     
	      elsif ( $line =~ /^-gt/i ) {
	        $line =~ s/-gt //i;
		$TEST_TYPE=$TEST_TYPES[2];
	      }

	      if ( $line =~ /^-cmd/i ) {
	        $line =~ s/-cmd //i;
		$line = qx/$line/;
		chomp($line);
		$line =~ s/ |\t//g;
	      }

	      @rc = &checkReferences($CLASS,$TEST_TYPE,
				     $sourceClass,$targetClass,$line,
				     $volatile);
	      $crc[0]=$rc[0]+$crc[0];   # ok
	      $crc[1]=$rc[1]+$crc[1];   # failed
	    }
	  }
        }
      }
    } # close : if class or association
  }
}
else { print "$CLASS --- consistence - syntax of input file not known\n"; }

&consistence_close_write_report();

print "-----------------------------------------------------------------------------------\n";
print "$CLASS --- Number of Tests where Status ok     : $crc[0]\n" if (defined $crc[0]);
print "$CLASS --- Number of Tests where Status failed : $crc[1]\n" if (defined $crc[1]);
print "\n\n";

close(INPUT_SYSTEM);

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
# Definition of Report File for Class Tests                                    #
#                                                                              #
#******************************************************************************#

sub consistence_class_write_report {
  # open Report File for this Class; if necessary one is created
  $^="CONSISTENCE_CLASS_TOP";
  $~="CONSISTENCE_CLASS";
  open(CONSISTENCE_CLASS,">> $REPORT_FILE") or die "can not create Report File for ".$CLASS;
  $OLD_HDL = select(CONSISTENCE_CLASS);
  write;
  close(CONSISTENCE_CLASS);
  select($OLD_HDL);

  $crc[0]++ if($rc[0] == 1);                # ok
  $crc[1]++ if( ( $rc[0] != 1 ) && 
		( $rc[0] != 0 ) && 
		( $rc[0] != 6 ) &&  
		( $rc[0] != 7 ) &&  
		( $rc[0] != 8 )   );        # failed

}

#******************************************************************************#
# Header
#

format CONSISTENCE_CLASS_TOP =
********************************************************************************
class : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
localtime()."\n";

--------------------------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CONSISTENCE_TYPE[0]
--------------------------------------------------------------------------------

.

#******************************************************************************#
# Line
#

format CONSISTENCE_CLASS =
@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$TEST_TYPE
Status        : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])
executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[3] if(defined $rc[3] && defined($VERBOSE));

.

#******************************************************************************#


#******************************************************************************#
#                                                                              #
# Definition of Report File for Property Tests                                 #
#                                                                              #
#******************************************************************************#

sub consistence_property_write_report {
  # open Report File for this Class; if necessary one is created
  $^="CONSISTENCE_PROPERTY_TOP";
  $~="CONSISTENCE_PROPERTY";
  open(CONSISTENCE_PROPERTY,">> $REPORT_FILE") or die "can not create Report File for ".$CLASS;
  $OLD_HDL = select(CONSISTENCE_PROPERTY);
  write;
  close(CONSISTENCE_PROPERTY);
  select($OLD_HDL);

  $crc[0]++ if($rc[0] == 1);                # ok
  $crc[1]++ if( ( $rc[0] != 1 ) && 
		( $rc[0] != 0 )   );        # failed
}

#******************************************************************************#
# Header
#

format CONSISTENCE_PROPERTY_TOP =
********************************************************************************
class : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
localtime()."\n";

--------------------------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CONSISTENCE_TYPE[1]
executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[3] if(defined $rc[3] && defined($VERBOSE));
--------------------------------------------------------------------------------

.

#******************************************************************************#
# Line
#

format CONSISTENCE_PROPERTY =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<     @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$PROPERTY_NAME, $TEST_TYPE
Status        : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])

.

#******************************************************************************#



#******************************************************************************#
#                                                                              #
# Definition of Report File for Instance Test                                  #
#                                                                              #
#******************************************************************************#

sub consistence_inst_write_report {
  # open Report File for this Class; if necessary one is created
  $^="CONSISTENCE_INST_TOP";
  $~="CONSISTENCE_INST";
  open(CONSISTENCE_INST,">> $REPORT_FILE") or die "can not create Report File for ".$CLASS;
  $OLD_HDL = select(CONSISTENCE_INST);
  write;
  close(CONSISTENCE_INST);
  select($OLD_HDL);

  $crc[0]++ if($rc[0] == 1);                # ok
  $crc[1]++ if( ( $rc[0] != 1 ) && 
		( $rc[0] != 0 ) && 
		( $rc[0] != 7 )   );        # failed
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
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CONSISTENCE_TYPE[2]
executed call : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[3] if(defined $rc[3] && defined($VERBOSE));
--------------------------------------------------------------------------------

.

#******************************************************************************#
# Line
#

format CONSISTENCE_INST =
RC     : @<<<<<<<<<<<<<
$rc[0] if (defined $rc[0])
Status : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rc[1] if (defined $rc[1])

.

#******************************************************************************#



#******************************************************************************#
#                                                                              #
# Definition of Report File for overall test status                            #
#                                                                              #
#******************************************************************************#

sub consistence_close_write_report {
  # open Report File for this Class; if necessary one is created
  $^="CONSISTENCE_CLOSE_TOP";
  $~="CONSISTENCE_CLOSE";
  open(CONSISTENCE_CLOSE,">> $REPORT_FILE") or die "can not create Report File for ".$CLASS;
  $OLD_HDL = select(CONSISTENCE_CLOSE);
  write;
  close(CONSISTENCE_CLOSE);
  select($OLD_HDL);
}

#******************************************************************************#
# Header
#

format CONSISTENCE_CLOSE_TOP =

--------------------------------------------------------------------------------
********************************************************************************
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$CLASS

.

#******************************************************************************#
# Line
#

format CONSISTENCE_CLOSE =
Number of Tests where Status ok     : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$crc[0] if (defined $crc[0])
Number of Tests where Status failed : @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$crc[1] if (defined $crc[1])

.

#******************************************************************************#



#******************************************************************************#
#                           end of consistence.pl                              #
#******************************************************************************#
