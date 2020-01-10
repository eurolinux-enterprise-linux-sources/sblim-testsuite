#!/usr/bin/perl
#
# cimom.pm
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
# This perl script initializes the CIMOM specific variables.
#

package cimom;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(PROTOCOL HOSTNAME NAMESPACE HOST WBEMFLAG);
@EXPORT_OK = 'ACCESS';

use strict;
use warnings;


my $host;
my $port;

our $PROTOCOL;
our $SCHEME="http";
our $ACCESS="";
our $HOSTNAME;
our $NAMESPACE;
our $WBEMFLAG="";

my @env=`env`;

foreach my $env_var (@env) {
    my @env_array = split('=',$env_var);

    if( $env_array[0] eq "SBLIM_TESTSUITE_ACCESS") {
	chomp($env_array[1]);
	$ACCESS=$env_array[1];
    }

    if( $env_array[0] eq "WBEMCLI_IND") {
	chomp($env_array[1]);
	my $alias = qx/head -1 $env_array[1]/;
	chomp $alias;
	$alias =~ s/.*: //;

	my @value = split(':',$alias);
	if(defined $value[3] && $value[2] =~ /\@/ ) {
	    my @user = split('@',$value[2]);
	    $value[1] =~ s/\/\///;
	    $ACCESS="$value[1]:$user[0]@";
	    $host=$user[1];
	    $port="$value[3]";
	}
	elsif(defined $value[2] ) {
	    $port="$value[2]";
	}
    }

    if( $env_array[0] eq "SBLIM_TESTSUITE_HOSTNAME") {
	chomp($env_array[1]);
	$host="$env_array[1]";
    }

    if( $env_array[0] eq "SBLIM_TESTSUITE_PORT") {
	chomp($env_array[1]);
	$port="$env_array[1]";
    }

    if( $env_array[0] eq "SBLIM_TESTSUITE_NAMESPACE") {
	chomp($env_array[1]);
	$NAMESPACE="$env_array[1]:";
    }

    if( $env_array[0] eq "SBLIM_TESTSUITE_PROTOCOL") {
	chomp($env_array[1]);
	$SCHEME="$env_array[1]";
    }


}

if(!defined $PROTOCOL) {
    $PROTOCOL="$SCHEME://$ACCESS";
    if ($SCHEME eq "https") {
	$WBEMFLAG="-noverify";
    }
}
if(!defined $HOSTNAME) {
    if(defined $port) {
	$HOSTNAME="$host:$port";
    }
    else {
	$HOSTNAME="$host:5988";
    }
}
if(!defined $NAMESPACE) {
    $NAMESPACE="/root/cimv2:";
}
our $HOST=$PROTOCOL.$HOSTNAME.$NAMESPACE;

#print "$PROTOCOL\n";
#print "$HOSTNAME\n";
#print "$NAMESPACE\n";
#print "$HOST\n";



our $ERROR_PREFIX="CIM_ERR_";
