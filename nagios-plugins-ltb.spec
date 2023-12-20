# No binaries here, do not build a debuginfo package
%global debug_package %{nil}

Name:    nagios-plugins-ltb
Version: 0.9
Release: 1%{?dist}
Summary: LDAP Tool Box Nagios plugins
License: GPL-3.0-only
URL:     https://github.com/ltb-project/nagios-plugins
Source0: https://github.com/ltb-project/nagios-plugins/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires: perl-generators
Requires: nagios-common


%description
This is a collection of Nagios plugins and event handlers designed to monitor
LDAP directories.


%prep
%setup -q -n nagios-plugins-%{version}


%build
# Nothing to build


%install
mkdir -p %{buildroot}%{_libdir}/nagios/plugins/eventhandlers/
install -p -m 0755 *.pl %{buildroot}%{_libdir}/nagios/plugins/
install -p -m 0755 restart_slapd.sh %{buildroot}%{_libdir}/nagios/plugins/eventhandlers/


%files
%license LICENSE
%doc README.md
%{_libdir}/nagios/plugins/*
%{_libdir}/nagios/plugins/eventhandlers/restart_slapd.sh


%changelog
* Tue Dec 19 2023 Xavier Bachelot <xavier@bachelot.org> - 0.9-1
- Initial package
