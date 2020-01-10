#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

# PUT YOUR PACKAGE INFO HERE. e.g.
#AC_INIT(<PACKAGE_NAME>, <PACKAGE_VERSION>, <PACKAGE_BUGREPORT>, <PACKAGE_TARBALL>)
AC_INIT(SBLIM Testsuite, 1.3.0, sblim-devel@lists.sourceforge.net, sblim-testsuite)

# CHANGE THIS TO THE RELATIVE PATHNAME OF *ONE* OF THE SOURCE FILES
AC_CONFIG_SRCDIR([run.sh])

# CHANGE THIS TO THE NAME OF THE RPM SPEC FILE
AC_CONFIG_FILES([sblim-testsuite.spec])

# DECLARE ANY SPECIAL CUSTOM CONFIGURE COMMAND LINE OPTIONS HERE

# ADD CHECKS FOR ANY SPECIAL REQUIRED PROGRAMS HERE. e.g.
AC_CHECK_PROG(PERL,perl,perl,not found)
AC_CHECK_PROG(WBEMCLI,wbemcli,wbemcli,not found)

# ADD CHECKS FOR ANY SPECIAL REQUIRED HEADER FILES HERE

# ADD CHECKS FOR ANY SPECIAL REQUIRED TYPEDEFS, STRUCTURES AND COMPILER OPTIONS HERE

# ADD CHECKS FOR ANY SPECIAL REQUIRED LIBRARY FUNCTIONS HERE

### NO CHANGES SHOULD BE NECESSARY BELOW
AC_CONFIG_FILES([Makefile])
AM_INIT_AUTOMAKE

# Check for required programs.
AC_PROG_LN_S

# Check for required headers

# Check for required CMPI header files (defined in acinclude.m4)

# Check for required libraries (defined in acinclude.m4)

# Check for CIM Server (defined in acinclude.m4)

# Display configuration options
echo "-------------------------------------------------------"
echo "Configuration for $PACKAGE complete."
echo ""
echo "Perl program is" $PERL
echo "WBEMCLI program is" $WBEMCLI
echo "-------------------------------------------------------"

# Generate configure scripts for the Makefile
AC_OUTPUT

echo "You may now run make"

