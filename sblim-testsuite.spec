%global debug_package %{nil}

Name:           sblim-testsuite
Version:        1.3.0
Release:        7%{?dist}
Summary:        SBLIM testsuite

Group:          Applications/System
License:        EPL
URL:            http://sblim.wiki.sourceforge.net/
Source0:        http://downloads.sourceforge.net/sblim/%{name}-%{version}.tar.bz2
BuildArch:      noarch

Requires:       perl >= 5.6
Requires:       sblim-wbemcli >= 1.5

Patch0:         sblim-testsuite-1.3.0-perl-errors.patch

%description
SBLIM automated testsuite scripts.

%prep
%setup -q
%patch0 -p1 -b .perl-errors

%build
%configure
make %{?_smp_mflags}

%install
make install DESTDIR=$RPM_BUILD_ROOT

%files
%doc %{_datadir}/doc/%{name}-%{version}
%{_datadir}/%{name}
%{_localstatedir}/lib/%{name}

%changelog
* Thu Feb 14 2013 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.3.0-7
- Rebuilt for https://fedoraproject.org/wiki/Fedora_19_Mass_Rebuild

* Mon Sep 10 2012 Vitezslav Crhonek <vcrhonek@redhat.com> - 1.3.0-6
- Fix issues found by fedora-review utility in the spec file

* Sat Jul 21 2012 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.3.0-5
- Rebuilt for https://fedoraproject.org/wiki/Fedora_18_Mass_Rebuild

* Sat Jan 14 2012 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.3.0-4
- Rebuilt for https://fedoraproject.org/wiki/Fedora_17_Mass_Rebuild

* Thu Jun 09 2011 Vitezslav Crhonek <vcrhonek@redhat.com> - 1.3.0-3
- Fix perl errors

* Wed Feb 09 2011 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.3.0-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_15_Mass_Rebuild

* Thu Dec  9 2010 Vitezslav Crhonek <vcrhonek@redhat.com> - 1.3.0-1
- Update to sblim-testsuite-1.3.0

* Sun Jul 26 2009 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.2.5-4
- Rebuilt for https://fedoraproject.org/wiki/Fedora_12_Mass_Rebuild

* Wed Feb 25 2009 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.2.5-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_11_Mass_Rebuild

* Tue Nov  4 2008 Vitezslav Crhonek <vcrhonek@redhat.com> - 1.2.5-2
- Remove debug package, fix URL, make setup quiet
- Spec file cleanup, rpmlint check

* Fri Oct 24 2008 Vitezslav Crhonek <vcrhonek@redhat.com> - 1.2.5-1
- Update to 1.2.5
  Resolves: #468327

* Thu Oct 28 2005 Viktor Mihajlovski <mihajlov@de.ibm.com> - 1.2.4-1
- New release

* Thu Jul 28 2005 Viktor Mihajlovski <mihajlov@de.ibm.com> - 1.2.3-0
- Updates for rpmlint complaints
