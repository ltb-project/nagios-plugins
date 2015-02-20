#! /usr/bin/perl -w

#==========================================================================
# Summary
#==========================================================================
# Check LMDB Usage
#
# Monitor pages used in an LMDB base
#
# Copyright (C) 2015 Clement OUDOT
# Copyright (C) 2015 LTB-project.org
#
#==========================================================================
# License: GPLv2+
#==========================================================================
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
# GPL License: http://www.gnu.org/licenses/gpl.txt
#==========================================================================

#==========================================================================
# Version
#==========================================================================
my $VERSION          = '0.1';
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

my $current = 0;
my $maximum = 0;

my $db_home;
my $mdb_stat;

GetOptions(
    'h'          => \$help,
    'help'       => \$help,
    'V'          => \$version,
    'version'    => \$version,
    'v+'         => \$verbose,
    'verbose+'   => \$verbose,
    'w:i'        => \$warning,
    'warning:i'  => \$warning,
    'c:i'        => \$critical,
    'critical:i' => \$critical,
    'f'          => \$perf_data,
    'perf_data'  => \$perf_data,
    'current!'   => \$current,
    'maximum!'   => \$maximum,
    'H:s'        => \$db_home,
    'db_home:s'  => \$db_home,
    'S:s'        => \$mdb_stat,
    'db_stat:s'  => \$mdb_stat,
);

#==========================================================================
# Usage
#==========================================================================
sub print_usage {
    print "Usage: \n";
    print "$progname -H <db_home> [-S <mdb_stat>] [-h] [-v] [-V]\n\n";
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

    print "\n\nGet LMBD used pages.\n\n";

    &print_usage;

    print "-v, --verbose\n";
    print "\tPrint extra debugging information.\n";
    print "-V, --version\n";
    print "\tPrint version and exit.\n";
    print "-h, --help\n";
    print "\tPrint this help message and exit.\n";
    print "-H, --db_home=STRING\n";
    print "\tHome of MDB files\n";
    print "-S, --mdb_stat=STRING\n";
    print "\tPath to mdb_stat utility.\n";
    print "-w, --warning=INTEGER\n";
    print "\tPercent of pages used to send a warning status.\n";
    print "-c, --critical=DOUBLE\n";
    print "\tPercent of pages used a critical status.\n";
    print "-f, --perf_data\n";
    print "\tDisplay performance data.\n";
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

# check if -h is used
sub check_db_home_param {
    if ( !defined($db_home) ) {
        printf "UNKNOWN: you have to define home of MDB files.\n";
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

#=========================================================================
# Main
#=========================================================================

# Options checks
&check_db_home_param();
&check_warning_param();
&check_critical_param();

# Default values
$mdb_stat ||= "/usr/local/openldap/sbin/mdb_stat";

# Run mdb_stat
#
my @result = `$mdb_stat -e $db_home`;

my $max_pages  = 0;
my $pages_used = 0;

foreach (@result) {
    if ( $_ =~ m/\s+Max pages:\s(\d+)/ ) {
        $max_pages = $1;
    }
    if ( $_ =~ m/\s+Number of pages used:\s(\d+)/ ) {
        $pages_used = $1;
    }

}

#==========================================================================
# Exit with Nagios codes
#==========================================================================

# Check percent of pages
#

my $percent_pages = int( $pages_used / $max_pages * 100 );

# Prepare PerfParse data
#

my $perfparse;
if ($perf_data) {
    $perfparse .=
      "|'percent_pages_used'=$percent_pages;$warning;$critical;0;100 ";
}

# Check CRITICAL/WARNING/OK
#
if ( $percent_pages > $critical ) {
    print "CRITICAL - $percent_pages% pages used $perfparse\n";
    exit $ERRORS{'CRITICAL'};
}
if ( $percent_pages > $warning ) {
    print "WARNING - $percent_pages% pages used, $perfparse\n";
    exit $ERRORS{'WARNING'};
}
if ( $percent_pages <= $warning ) {
    print "OK - $percent_pages% pages used $perfparse\n";
    exit $ERRORS{'OK'};
}

exit $ERRORS{'UNKNOWN'};

