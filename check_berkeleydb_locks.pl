#! /usr/bin/perl -w

#==========================================================================
# Summary
#==========================================================================
# Check LDAP query
#
# Get BerkeleyDB max locks used
#
# Copyright (C) 2012 Clement OUDOT
# Copyright (C) 2012 Joel SAUNIER
# Copyright (C) 2012 LTB-project.org
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
my $VERSION          = '0.5';
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
my $db_stat;

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
    'S:s'        => \$db_stat,
    'db_stat:s'  => \$db_stat,
);

#==========================================================================
# Usage
#==========================================================================
sub print_usage {
    print "Usage: \n";
    print "$progname -H <db_home> [-S <db_stat>] [-h] [-v] [-V]\n\n";
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

    print "\n\nGet BerkeleyDB maximum and current locks used.\n\n";

    &print_usage;

    print "-v, --verbose\n";
    print "\tPrint extra debugging information.\n";
    print "-V, --version\n";
    print "\tPrint version and exit.\n";
    print "-h, --help\n";
    print "\tPrint this help message and exit.\n";
    print "-H, --db_home=STRING\n";
    print "\tHome of BDB files\n";
    print "-S, --db_stat=STRING\n";
    print "\tPath to db_stat utility.\n";
    print "-w, --warning=INTEGER\n";
    print
"\tPercent of locks used to send a warning status.\n\tUse max locks by default, unless --current and --nomaximum are set\n";
    print "-c, --critical=DOUBLE\n";
    print
"\tPercent of locks used a critical status.\n\tUse max locks by default, unless --current and --nomaximum are set.\n";
    print "-f, --perf_data\n";
    print
"\tDisplay performance data.\n\tSet --maximum if --nocurrent and --nomaximum are set.\n";
    print "--current\n";
    print
"\tDisplay performance data for current locks/lockers/lock objects.\n\tDefault to --nocurrent\n";
    print "--maximum\n";
    print
"\tDisplay performance data for maximum locks/lockers/lock objects.\n\tDefault to --nomaximum\n";
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
        printf "UNKNOWN: you have to define home of BDB files.\n";
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
$db_stat ||= "/usr/local/berkeleydb/bin/db_stat";
$maximum = 1 if ( $current == 0 and $maximum == 0 );

# Run db_stat
#
my @result = `$db_stat -c -h $db_home`;

my $max_locks_possible        = 0;
my $max_lockers_possible      = 0;
my $max_lock_objects_possible = 0;
my $max_locks                 = 0;
my $max_lockers               = 0;
my $max_lock_objects          = 0;
my $current_locks             = 0;
my $current_lockers           = 0;
my $current_lock_objects      = 0;

foreach (@result) {

    if ( $_ =~ m/(\d+)\s*Maximum number of locks possible/ ) {
        $max_locks_possible = $1;
    }
    if ( $_ =~ m/(\d+)\s*Maximum number of lockers possible/ ) {
        $max_lockers_possible = $1;
    }
    if ( $_ =~ m/(\d+)\s*Maximum number of lock objects possible/ ) {
        $max_lock_objects_possible = $1;
    }
    if ( $_ =~ m/(\d+)\s*Maximum number of locks at any one time/ ) {
        $max_locks = $1;
    }
    if ( $_ =~ m/(\d+)\s*Maximum number of lockers at any one time/ ) {
        $max_lockers = $1;
    }
    if ( $_ =~ m/(\d+)\s*Maximum number of lock objects at any one time/ ) {
        $max_lock_objects = $1;
    }
    if ( $_ =~ m/(\d+)\s*Number of current locks/ )   { $current_locks   = $1 }
    if ( $_ =~ m/(\d+)\s*Number of current lockers/ ) { $current_lockers = $1 }
    if ( $_ =~ m/(\d+)\s*Number of current lock objects/ ) {
        $current_lock_objects = $1;
    }

}

#==========================================================================
# Exit with Nagios codes
#==========================================================================

# Prepare PerfParse data
my $perfparse = "|";
if ($perf_data) {
    my $warnvalue = 0;
    my $critvalue = 0;

    if ($current) {
        $warnvalue = int( ( $max_locks_possible * $warning ) / 100 );
        $critvalue = int( ( $max_locks_possible * $critical ) / 100 );
        $perfparse .=
"'current_locks'=$current_locks;$warnvalue;$critvalue;0;$max_locks_possible ";

        $warnvalue = int( ( $max_lockers_possible * $warning ) / 100 );
        $critvalue = int( ( $max_lockers_possible * $critical ) / 100 );
        $perfparse .=
"'current_lockers'=$current_lockers;$warnvalue;$critvalue;0;$max_lockers_possible ";

        $warnvalue = int( ( $max_lock_objects_possible * $warning ) / 100 );
        $critvalue = int( ( $max_lock_objects_possible * $critical ) / 100 );
        $perfparse .=
"'current_lock_objects'=$current_lock_objects;$warnvalue;$critvalue;0;$max_lock_objects_possible ";
    }

    if ($maximum) {
        $warnvalue = int( ( $max_locks_possible * $warning ) / 100 );
        $critvalue = int( ( $max_locks_possible * $critical ) / 100 );
        $perfparse .=
          "'max_locks'=$max_locks;$warnvalue;$critvalue;0;$max_locks_possible ";

        $warnvalue = int( ( $max_lockers_possible * $warning ) / 100 );
        $critvalue = int( ( $max_lockers_possible * $critical ) / 100 );
        $perfparse .=
"'max_lockers'=$max_lockers;$warnvalue;$critvalue;0;$max_lockers_possible ";

        $warnvalue = int( ( $max_lock_objects_possible * $warning ) / 100 );
        $critvalue = int( ( $max_lock_objects_possible * $critical ) / 100 );
        $perfparse .=
"'max_lock_objects'=$max_lock_objects;$warnvalue;$critvalue;0;$max_lock_objects_possible ";
    }

}

# Check percent of locks
#

my $percent_max_locks   = int( $max_locks / $max_locks_possible * 100 );
my $percent_max_lockers = int( $max_lockers / $max_lockers_possible * 100 );
my $percent_max_lock_objects =
  int( $max_lock_objects / $max_lock_objects_possible * 100 );

my $percent_curr_locks = int( $current_locks / $max_locks_possible * 100 );
my $percent_curr_lockers =
  int( $current_lockers / $max_lockers_possible * 100 );
my $percent_curr_lock_objects =
  int( $current_lock_objects / $max_lock_objects_possible * 100 );

# Check CRITICAL/WARNING/OK
#
if ($maximum) {
    if (   $percent_max_locks > $critical
        || $percent_max_lockers > $critical
        || $percent_max_lock_objects > $critical )
    {
        print
"CRITICAL - $percent_max_locks% locks, $percent_max_lockers% lockers, $percent_max_lock_objects% lock_objects $perfparse\n";
        exit $ERRORS{'CRITICAL'};
    }
    if (   $percent_max_locks > $warning
        || $percent_max_lockers > $warning
        || $percent_max_lock_objects > $warning )
    {
        print
"WARNING - $percent_max_locks% locks, $percent_max_lockers% lockers, $percent_max_lock_objects% lock_objects $perfparse\n";
        exit $ERRORS{'WARNING'};
    }
    if (   $percent_max_locks <= $warning
        && $percent_max_lockers <= $warning
        && $percent_max_lock_objects <= $warning )
    {
        print
"OK - $percent_max_locks% locks, $percent_max_lockers% lockers, $percent_max_lock_objects% lock_objects $perfparse\n";
        exit $ERRORS{'OK'};
    }
}

if ($current) {
    if (   $percent_curr_locks > $critical
        || $percent_curr_lockers > $critical
        || $percent_curr_lock_objects > $critical )
    {
        print
"CRITICAL - $percent_curr_locks% locks, $percent_curr_lockers% lockers, $percent_curr_lock_objects% lock_objects $perfparse\n";
        exit $ERRORS{'CRITICAL'};
    }
    if (   $percent_curr_locks > $warning
        || $percent_curr_lockers > $warning
        || $percent_curr_lock_objects > $warning )
    {
        print
"WARNING - $percent_curr_locks% locks, $percent_curr_lockers% lockers, $percent_curr_lock_objects% lock_objects $perfparse\n";
        exit $ERRORS{'WARNING'};
    }
    if (   $percent_curr_locks <= $warning
        && $percent_curr_lockers <= $warning
        && $percent_curr_lock_objects <= $warning )
    {
        print
"OK - $percent_curr_locks% locks, $percent_curr_lockers% lockers, $percent_curr_lock_objects% lock_objects $perfparse\n";
        exit $ERRORS{'OK'};
    }
}

exit $ERRORS{'UNKNOWN'};

