#!/usr/bin/perl -w

#====================================================================
# What's this ?
#====================================================================
# Script designed for Nagios http://www.nagios.org
# Checks the response time of an LDAP Server doing a search on RootDSE
# It uses threads if parameter -n is filled (threads require Perl 5.8)
# Returns Nagios Code
#
# Copyright (C) 2004 Clement OUDOT
# Copyright (C) 2009-2015 LTB-project.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# GPL Licence : http://www.gnu.org/licenses/gpl.txt
#====================================================================

#==========================================================================
# Version
#==========================================================================
my $VERSION          = '0.8';
my $TEMPLATE_VERSION = '1.0.0';

#==========================================================================
# Modules
#==========================================================================
use strict;
use lib
  qw(/usr/local/nagios/libexec /usr/lib/nagios/plugins /usr/lib64/nagios/plugins);
use utils qw /$TIMEOUT %ERRORS &print_revision &support/;
use Getopt::Long;
&Getopt::Long::config('bundling');
use File::Basename;
use Net::LDAP;
use Time::HiRes qw(gettimeofday);

#==========================================================================
# Options
#==========================================================================
my $progname = basename($0);
my $help;
my $version;
my $verbose = 0;
my $host;
my $warning;
my $critical;
my $mode;
my $logname;
my $authentication;
my $log_file;
my $perf_data;
my $name;
my $port;
my $timeout = $TIMEOUT;
my $regexp;
my $eregexp;
my $exclude;
my $minute = 60;
my $url;

# For LDAP plugins
my $ldap_binddn;
my $ldap_bindpw;
my $ldap_filter;
my $ldap_base;
my $ldap_scope;

my $nb_threads;

GetOptions(
    'h'            => \$help,
    'help'         => \$help,
    'V'            => \$version,
    'version'      => \$version,
    'v+'           => \$verbose,
    'verbose+'     => \$verbose,
    'H:s'          => \$host,
    'host:s'       => \$host,
    'w:i'          => \$warning,
    'warning:i'    => \$warning,
    'c:i'          => \$critical,
    'critical:i'   => \$critical,
    'm:s'          => \$mode,
    'mode:s'       => \$mode,
    'f'            => \$perf_data,
    'perf_data'    => \$perf_data,
    'p:i'          => \$port,
    'port:i'       => \$port,
    't:i'          => \$timeout,
    'timeout:i'    => \$timeout,
    'D:s'          => \$ldap_binddn,
    'binddn:s'     => \$ldap_binddn,
    'P:s'          => \$ldap_bindpw,
    'bindpw:s'     => \$ldap_bindpw,
    'F:s'          => \$ldap_filter,
    'filter:s'     => \$ldap_filter,
    'b:s'          => \$ldap_base,
    'base:s'       => \$ldap_base,
    's:s'          => \$ldap_scope,
    'scope:s'      => \$ldap_scope,
    'n:i'          => \$nb_threads,
    'nb_threads:i' => \$nb_threads,
);

#==========================================================================
# Usage
#==========================================================================
sub print_usage {
    print "Usage: \n";
    print "$progname -H <hostname> [-n nb_threads] [-h] [-v]\n\n";
    print "Use option --help for more information\n\n";
    print "$progname comes with ABSOLUTELY NO WARRANTY\n\n";
}

#=========================================================================
# Version
#=========================================================================
if ($version) {
    &print_revision( $progname,
        "\$Revision: $VERSION (TPL: $TEMPLATE_VERSION)\$" );
    exit $ERRORS{'UNKNOWN'};
}

#=========================================================================
# Help
#=========================================================================
if ($help) {
    &print_revision( $progname, "\$Revision: $VERSION\$" );

    print "\n\nRequest LDAP server and monitor response time.\n\n";

    &print_usage;

    print "-v, --verbose\n";
    print "\tPrint extra debugging information.\n";
    print "-V, --version\n";
    print "\tPrint version and exit.\n";
    print "-h, --help\n";
    print "\tPrint this help message and exit.\n";
    print "-H, --host=STRING\n";
    print
"\tIP or name (FQDN) of the directory. You can use URI (ldap://, ldaps://, ldap+tls://)\n";
    print "-p, --port=INTEGER\n";
    print "\tDirectory port to connect to.\n";
    print "-w, --warning=INTEGER\n";
    print "\tTime limit to return a warning status.\n";
    print "-c, --critical=DOUBLE\n";
    print "\tTime limit to return a critical status.\n";
    print "-f, --perf_data\n";
    print "\tDisplay performance data.\n";
    print "-t, --timeout=INTEGER\n";
    print "\tSeconds before connection times out (default: $TIMEOUT).\n";
    print "-D, --binddn=STRING\n";
    print "\tBind DN. Bind anonymous if not present.\n";
    print "-P, --bindpw=STRING\n";
    print "\tBind passwd. Need the Bind DN option to work.\n";
    print "-F, --filter=STRING\n";
    print "\tLDAP search filter.\n";
    print "-b, --base=STRING\n";
    print "\tLDAP search base.\n";
    print "-s, --scope=STRING\n";
    print "\tLDAP search scope\n";
    print "-n, --nb_threads=INTEGER\n";
    print "\tNumber of threads\n";
    print "\n";

    &support;

    exit $ERRORS{'UNKNOWN'};
}

#=========================================================================
# Functions
#=========================================================================

# DEBUG function
sub verbose {
    my $output_code = shift;
    my $text        = shift;
    if ( $verbose >= $output_code ) {
        printf "VERBOSE $output_code ===> %s\n", $text;
    }
}

# check if -H is used
sub check_host_param {
    if ( !defined($host) ) {
        printf "UNKNOWN: you have to define a hostname.\n";
        exit $ERRORS{UNKNOWN};
    }
}

# check if -w is used
sub check_warning_param {
    if ( !defined($warning) ) {
        printf "UNKNOWN: you have to define a warning thresold.\n";
        exit $ERRORS{UNKNOWN};
    }
}

# check if -c is used
sub check_critical_param {
    if ( !defined($critical) ) {
        printf "UNKNOWN: you have to define a critical thresold.\n";
        exit $ERRORS{UNKNOWN};
    }
}

#====================================================================
# Main program
#====================================================================

# Options checks
&check_host_param();
&check_warning_param();
&check_critical_param();

# Default values
$ldap_base ||= "";
$ldap_scope ||= "base";
$ldap_filter ||= "(objectClass=*)";
$nb_threads ||= 0;

my $time;

if ($nb_threads) {

    use threads;

    my @thread;
    my $result = 0;

    for ( my $i = 0 ; $i < $nb_threads ; $i++ ) {
        $thread[$i] = threads->create( "test_ldap", undef );
    }
    for ( my $i = 0 ; $i < $nb_threads ; $i++ ) {
        $result += $thread[$i]->join();
    }

    # Average time
    $time = ( $result / $nb_threads );
}

else {
    $time = &test_ldap;
}

$time = substr( $time, 0, 5 );

#==========================================================================
# Exit with Nagios codes
#==========================================================================

# Prepare PerfParse data
#

my $perfparse = "";
if ($perf_data) {
    $perfparse .=
      "|'time'=$time;$warning;$critical;0";
}

if ( $time < $warning ) {
    print "OK - $time second response time $perfparse\n";
    exit $ERRORS{'OK'};
}
elsif ( $time < $critical ) {
    print "WARNING - $time second response time $perfparse\n";
    exit $ERRORS{'WARNING'};
}
else {
    print "CRITICAL - $time second response time $perfparse\n";
    exit $ERRORS{'CRITICAL'};
}

sub test_ldap {

    # Start timer
    my $start_time = gettimeofday();

    # LDAP Connection
    my $ldap = Net::LDAP->new(
        $host,
        port    => $port,
        version => $version,
        timeout => $timeout,
    );

    unless ($ldap) {
        print "CRITICAL - Problem with LDAP connection\n";
        exit $ERRORS{'CRITICAL'};
    }

    # Bind
    if ( $ldap_binddn && $ldap_bindpw ) {

        # Bind witch credentials
        my $req_bind = $ldap->bind( $ldap_binddn, password => $ldap_bindpw );

        if ( $req_bind->code ) {
            print "UNKNOWN - Bind Error "
              . $req_bind->code . " : "
              . $req_bind->error . "\n";
            exit $ERRORS{'UNKNOWN'};
        }
    }

    else {

        # Bind anonymous
        my $req_bind = $ldap->bind();

        if ( $req_bind->code ) {
            print "UNKNOWN - Bind Error "
              . $req_bind->code . " : "
              . $req_bind->error . "\n";
            exit $ERRORS{'UNKNOWN'};
        }
    }

    # Base Search
    my $req_search = $ldap->search(
        base   => $ldap_base,
        scope  => $ldap_scope,
        filter => $ldap_filter,
        attrs  => ['1.1'],
    );

    if ( $req_search->code ) {
        print "UNKNOWN - Search Error "
          . $req_search->code . " : "
          . $req_search->error . "\n";
        $ldap->unbind;
        exit $ERRORS{'UNKNOWN'};
    }

    # Unbind
    $ldap->unbind();

    # Stop Timer
    my $end_time = gettimeofday();

    my $time = $end_time - $start_time;

    # Return $time
    return $time;
}

