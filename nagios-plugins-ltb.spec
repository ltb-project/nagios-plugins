# No binaries here, do not build a debuginfo package. This is a binary
# package on RHEL/Fedora because it depends on %%_libdir which is arch
# dependent
%global debug_package %{nil}

# Filter perl(utils) dep from %%{_libdir}/nagios/plugins/utils.pm
%global __requires_exclude ^perl\\(utils\\)
# All of the default filters
%{?perl_default_filter}

Name:    nagios-plugins-ltb
Version: 0.9
Release: 4%{?dist}
Summary: LDAP Tool Box Nagios plugins
License: GPL-3.0-only
URL:     https://github.com/ltb-project/nagios-plugins
Source0: https://github.com/ltb-project/nagios-plugins/archive/v%{version}/%{name}-%{version}.tar.gz
# https://github.com/ltb-project/nagios-plugins/commit/bf772032b84cd9eb624f26c4748c93050f6196bc.patch
Patch0:  nagios-plugins-ltb-0.9-rename_licence.patch

BuildRequires: perl-generators
Requires: nagios-plugins-perl


%description
This is a collection of Nagios plugins and event handlers designed to monitor
LDAP directories.


%prep
%autosetup -n nagios-plugins-%{version} -p1


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


%changelog
* Sat Oct 17 2026 Todd Zullinger <tmz@pobox.com> - 0.9-4
- Filter deps from %%{_libdir}/nagios/plugins
- Require nagios-plugins-perl for utils.pm

* Wed Oct 14 2026 Xavier Bachelot <xavier@bachelot.org> - 0.9-3
- Tweaks following review

* Wed Dec 20 2023 Xavier Bachelot <xavier@bachelot.org> - 0.9-2
- Add upstream patch to rename LICENCE to LICENSE

* Tue Dec 19 2023 Xavier Bachelot <xavier@bachelot.org> - 0.9-1
- Initial package
