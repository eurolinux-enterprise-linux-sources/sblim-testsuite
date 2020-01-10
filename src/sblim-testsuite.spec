#
# $Id: sblim-testsuite.spec.in,v 1.4 2009/06/19 00:27:08 tyreld Exp $
#
# Package spec for sblim-testsuite
#

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch

Summary: SBLIM testsuite
Name: sblim-testsuite
Version: 1.3.0
Release: 1
Group: Systems Management/Base
URL: http://www.sourceforge.net
License: EPL

Source0: http://prdownloads.sourceforge.net/sblim/%{name}-%{version}.tar.bz2

Requires: perl >= 5.6
Requires: sblim-wbemcli >= 1.5

%Description
SBLIM automated testsuite scripts

%prep

%setup

%build

%configure
make

%install
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT install


%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc %{_datadir}/doc/%{name}-%{version}
%{_datadir}/%{name}
%{_localstatedir}/lib/%{name}

%changelog

* Thu Oct 28 2005 Viktor Mihajlovski <mihajlov@de.ibm.com> 1.2.4-1
  - New release

* Thu Jul 28 2005 Viktor Mihajlovski <mihajlov@de.ibm.com> 1.2.3-0
  - Updates for rpmlint complaints
