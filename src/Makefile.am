# $Id: Makefile.am,v 1.3 2009/06/19 00:27:08 tyreld Exp $
# ==================================================================
# (C) Copyright IBM Corp. 2005, 2009
#
# THIS FILE IS PROVIDED UNDER THE TERMS OF THE ECLIPSE PUBLIC LICENSE
# ("AGREEMENT"). ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS FILE
# CONSTITUTES RECIPIENTS ACCEPTANCE OF THE AGREEMENT.
#
# You can obtain a current copy of the Eclipse Public License from
# http://www.opensource.org/licenses/eclipse-1.0.php
#
# Author:       Viktor Mihajlovski <mihajlov@de.ibm.com>
# Contributors: Dr. Gareth S. Bestor <bestorga@us.ibm.com>
# Description:  Automake input file for SBLIM testsuite
# ==================================================================

# Various directories

pkgstatedir=$(localstatedir)/lib/$(PACKAGE)
systemtestdir=$(pkgdatadir)/system/linux
consistencetestdir=$(pkgdatadir)/cim

#
# Automake instructions
#

# docdir defines where the documentation goes
docdir=$(datadir)/doc/$(PACKAGE)-$(VERSION)

#
# Automake instructions for documentation
#
doc_DATA=README AUTHORS COPYING 

# We must explicity add the RPM spec file to the distribution package
EXTRA_DIST=sblim-testsuite.spec

# We must explicity add all the testsuite files to the distribution package
consistencetest_DATA=cim/SampleClass.cim 
systemtest_DATA=system/linux/SampleClass.system \
	system/linux/createKeyFiles.sh.sample
pkgdata_SCRIPTS=associator.pm  cimom.pm  consistence.pm  instance.pm \
	consistence.pl interface.pl run.sh
EXTRA_DIST+=$(pkgdata_SCRIPTS) $(consistencetest_DATA) $(systemtest_DATA)

install-data-local:
	test -d $(DESTDIR)$(pkgstatedir)/stat || $(mkdir_p) $(DESTDIR)$(pkgstatedir)/stat
	$(LN_S) -f $(pkgstatedir)/stat $(DESTDIR)$(pkgdatadir)
