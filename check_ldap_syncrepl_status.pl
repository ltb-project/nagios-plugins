#! /usr/bin/perl -w

#==========================================================================
# Summary
#==========================================================================
# Check OpenLDAP Syncrepl status
#
# To know if a slave and a master are in sync, get the ContextCSN
# and compare them
#
# Copyright (C) 2007 Clement OUDOT
# Copyright (C) 2009 LTB-project.org
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
use POSIX;
use Net::LDAP;
use Time::Piece;

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

# For SNMP plugins
my $snmp_version;
my $snmp_v1;
my $snmp_v2c;
my $snmp_v3;
my $community;
my $seclevel;
my $authproto;
my $privpasswd;
my $oid;

# For LDAP plugins
my $ldap_binddn;
my $ldap_bindpw;
my $ldap_binduri;
my $slave_ldap_suffix;
my $master_ldap_suffix;
my $ldap_serverid;
my $ldap_singlemaster;

GetOptions(
    'h'          => \$help,
    'help'       => \$help,
    'V'          => \$version,
    'version'    => \$version,
    'v+'         => \$verbose,
    'verbose+'   => \$verbose,
    'H:s'        => \$host,
    'host:s'     => \$host,
    'w:f'        => \$warning,
    'warning:f'  => \$warning,
    'c:f'        => \$critical,
    'critical:f' => \$critical,

    #'l:s'=> \$logname,'logname:s'=> \$logname,
    #'a:s'=> \$authentication,
    #'authentication:s'=> \$authentication,
    #'F:s'=> \$log_file,'log_file:s'=> \$log_file,
    'f'         => \$perf_data,
    'perf_data' => \$perf_data,
    'n:s'       => \$name,
    'name:s'    => \$name,
    'p:i'       => \$port,
    'port:i'    => \$port,
    't:i'       => \$timeout,
    'timeout:i' => \$timeout,

    #'r:s'=> \$regexp,'regexp:s'=> \$regexp,
    #'e:s'=> \$exclude,'exclude:s'=> \$exclude,
    #'m:s'=> \$minute,'minute:s'=> \$minute,
    #'u:s'=> \$url,'url:s'=> \$url,
    # For SNMP plugins
    #'snmp_version:s'=> \$snmp_version,'1'=> \$snmp_v1,
    #'2'=> \$snmp_v2c,'3'=> \$snmp_v3,
    #'C:s'=> \$community,'community:s'=> \$community,
    #'L:s'=> \$seclevel,'seclevel:s'=> \$seclevel,
    #'A:s'=> \$authproto,'authproto:s'=> \$authproto,
    #'X:s'=> \$privpasswd,'privpasswd:s'=> \$privpasswd,
    #'o:s'=> \$oid,'oid:s'=> \$oid,
    # For LDAP plugins
    'D:s'            => \$ldap_binddn,
    'binddn:s'       => \$ldap_binddn,
    'P:s'            => \$ldap_bindpw,
    'bindpw:s'       => \$ldap_bindpw,
    'U:s'            => \$ldap_binduri,
    'binduri:s'      => \$ldap_binduri,
    'S:s'            => \$slave_ldap_suffix,
    'suffix:s'       => \$slave_ldap_suffix,
    'M:s'            => \$master_ldap_suffix,
    'mastersuffix:s' => \$master_ldap_suffix,
    'I:s'            => \$ldap_serverid,
    'serverid:s'     => \$ldap_serverid,
    's'              => \$ldap_singlemaster,
    'singlemaster'   => \$ldap_singlemaster,
);

# Fix SMNP Version
unless ($snmp_version) {
    $snmp_version = "1"  if $snmp_v1;
    $snmp_version = "2c" if $snmp_v2c;
    $snmp_version = "3"  if $snmp_v3;
}

#==========================================================================
# Usage
#==========================================================================
sub print_usage {
    print "Usage: \n";
    print "$progname -H <hostname> [-h] [-v] [-V]\n\n";
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

    print
"\n\nConnect to master and slave directories,\nsearch for ContextCSN and check if they are in sync.\n\n";

    &print_usage;

    print "-v, --verbose\n";
    print "\tPrint extra debugging information.\n";
    print "-V, --version\n";
    print "\tPrint version and exit.\n";
    print "-h, --help\n";
    print "\tPrint this help message and exit.\n";
    print "-H, --host=STRING\n";
    print
"\tIP or name (FQDN) of the slave directory. You can use URI (ldap://, ldaps://, ldap+tls://)\n";
    print "-p, --port=INTEGER\n";
    print "\tSlave directory port to connect to.\n";
    print "-w, --warning=DOUBLE\n";
    print "\t Level to return a warning status.\n";
    print "-c, --critical=DOUBLE\n";
    print "\tLevel to return a critical status.\n";

    #print "-l, --logname=STRING\n";
    #print "\tUser id for login.\n";
    #print "-a, --authentication=STRING\n";
    #print "\tSSH private key file.\n";
    #print "-F, --log_file=STRING\n";
    #print "\tStatus or log file.\n";
    print "-f, --perf_data\n";
    print "\tDisplay performance data.\n";

    #print "-n, --name=STRING\n";
    #print "\tName (database, table, service, ...).\n";
    print "-t, --timeout=INTEGER\n";
    print "\tSeconds before connection times out (default: $TIMEOUT).\n";

    #print "-r, --regexp=STRING\n";
    #print "\tCase sensitive regular expression.\n";
    #print "-e, --exclude=STRING\n";
    #print "\nExclude this regular expression.\n";
    #print "-u, --url=STRING\n";
    #print "\tURL.\n";
    #print "-1, -2, -3, --snmp_version=(1|2c|3)\n";
    #print "\tSNMP protocol version.\n";
    #print "-C, --community=STRING\n";
    #print "\tSNMP community (v1 and v2c).\n";
    #print "-L, --seclevel=(noAuthNoPriv|authNoPriv|authPriv))\n";
    #print "\tSNMP security level (v3).\n";
    #print "-A, --authproto=(MD5|SHA)\n";
    #print "\tSNMP authentication protocol (v3).\n";
    #print "-X, --privpasswd=STRING\n";
    #print "\tSNMP cipher password (v3).\n";
    #print "-o, --oid=STRING\n";
    #print "\tSNMP OID.\n";
    print "-D, --binddn=STRING\n";
    print
"\tBind DN to master and slave directories. Bind anonymous if not present.\n";
    print "-P, --bindpw=STRING\n";
    print
"\tBind passwd to master and slave directories. Need the Bind DN option to work.\n";
    print "-U, --binduri=STRING\n";
    print
"\tBind URI (ldap://, ldaps://, ldap+tls://) of the master directory. Retrieve this value in cn=monitor if not present.\n";
    print "-S, --suffix=STRING\n";
    print "-M, --mastersuffix=STRING\n";
    print
"\tSuffix of the directories. Retrieve this value in RootDSE if not present.\n";
    print "-I, --serverid=STRING\n";
    print "\tSID of the syncrepl link\n";
    print "-s, --singlemaster\n";
    print "\tClassic master-slave. No multi-mastering\n";
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
        &print_usage;
        exit $ERRORS{UNKNOWN};
    }
}

# check if -w is used
sub check_warning_param {
    if ( !defined($warning) ) {
        printf "UNKNOWN: you have to define a warning threshold.\n";
        &print_usage;
        exit $ERRORS{UNKNOWN};
    }
}

# check if -c is used
sub check_critical_param {
    if ( !defined($critical) ) {
        printf "UNKNOWN: you have to define a critical threshold.\n";
        &print_usage;
        exit $ERRORS{UNKNOWN};
    }
}

# Parse CSN
# See http://www.openldap.org/faq/index.cgi?_highlightWords=csn&file=1145
sub parse_csn {
    &verbose( '3', "Enter &parse_csn" );
    my ($csn) = @_;
    my ( $utime, $mtime, $count, $sid, $mod ) =
      ( $csn =~ m/(\d{14})\.?(\d{6})?Z#(\w{6})#(\w{2,3})#(\w{6})/g );
    &verbose( '2', "Parse $csn into $utime - $count - $sid - $mod" );
    &verbose( '3', "Leave &parse_csn" );
    return ( $utime, $count, $sid, $mod );
}

# Bind to LDAP server
sub get_ldapconn {
    &verbose( '3', "Enter &get_ldapconn" );
    my ( $server, $binddn, $bindpw ) = @_;
    my ( $useTls, $tlsParam );

    # Manage ldap+tls:// URI
    if ( $server =~ m{^ldap\+tls://([^/]+)/?\??(.*)$} ) {
        $useTls   = 1;
        $server   = $1;
        $tlsParam = $2 || "";
    }
    else {
        $useTls = 0;
    }

    my $ldap = Net::LDAP->new( $server, timeout => $timeout );

    return ('1') unless ($ldap);
    &verbose( '2', "Connected to $server" );

    if ($useTls) {
        my %h = split( /[&=]/, $tlsParam );
        my $message = $ldap->start_tls(%h);
        $message->code
          && &verbose( '1', $message->error )
          && return ( $message->code, $message->error );
        &verbose( '2', "startTLS success on $server" );
    }

    if ( $binddn && $bindpw ) {

        # Bind witch credentials
        my $req_bind = $ldap->bind( $binddn, password => $bindpw );
        $req_bind->code
          && &verbose( '1', $req_bind->error )
          && return ( $req_bind->code, $req_bind->error );
        &verbose( '2', "Bind with $binddn" );
    }
    else {
        my $req_bind = $ldap->bind();
        $req_bind->code
          && &verbose( '1', $req_bind->error )
          && return ( $req_bind->code, $req_bind->error );
        &verbose( '2', "Bind anonymous" );
    }
    &verbose( '3', "Leave &get_ldapconn" );
    return ( '0', $ldap );
}

# Get the master URI from cn=monitor
sub get_masteruri {
    &verbose( '3', "Enter &get_masteruri" );
    my ($ldapconn) = @_;
    my $result;
    my $message;
    my $entry;
    $message = $ldapconn->search(
        base   => 'cn=monitor',
        scope  => 'sub',
        filter => '(&(namingContexts=*)(MonitorUpdateRef=*))',
        attrs  => [ 'monitorupdateref', 'namingContexts' ]
    );
    $message->code
      && &verbose( '1', $message->error )
      && return ( $message->code, $message->error );
    $entry = $message->entry(0);
    return ( 1, "No data" ) unless $entry;
    &verbose( '2',
        "Found Master URI: " . $entry->get_value('monitorupdateref') );
    &verbose( '3', "Leave &get_masteruri" );
    return ( 0, $entry->get_value('monitorupdateref') );
}

# Get the suffix from RootDSE
sub get_suffix {
    &verbose( '3', "Enter &get_suffix" );

    # Return the first namingContext of the RootDSE
    my ($ldapconn) = @_;
    my $result;
    my $message;
    my $entry;
    $message = $ldapconn->search(
        base   => '',
        scope  => 'base',
        filter => '(objectClass=*)',
        attrs  => ['namingcontexts']
    );
    $message->code
      && &verbose( '1', $message->error )
      && return ( $message->code, $message->error );
    $entry = $message->entry(0);
    return ( 1, "No data" ) unless $entry;
    &verbose( '2', "Found suffix: " . $entry->get_value('namingcontexts') );
    &verbose( '3', "Leave &get_suffix" );
    return ( 0, $entry->get_value('namingcontexts') );
}

# Get the ContextCSN
sub get_contextcsn {
    &verbose( '3', "Enter &get_contextCSN" );
    my ( $ldapconn, $base, $serverid ) = @_;
    my $result;
    my $message;
    my $entry;
    my $contextcsn;
    $message = $ldapconn->search(
        base   => $base,
        scope  => 'base',
        filter => '(objectclass=*)',
        attrs  => ['contextCSN']
    );
    $message->code
      && &verbose( '1', $message->error )
      && return ( $message->code, $message->error );
    $entry = $message->entry(0);
    return ( 1, "No data" ) unless $entry;

    # Get values
    foreach ( $entry->get_value('contextCSN') ) {
        &verbose( '2', "Found ContextCSN: " . $_ );

        # Keep only ContextCSN with SID
        my @csn = &parse_csn($_);
        if ( !$ldap_singlemaster ) {
            if ( $serverid eq $csn[2] ) {
                $contextcsn = $_;
                &verbose( '2',
                    "ContextCSN match with SID $serverid: " . $contextcsn );
                last;
            }
        }
        else {
            $contextcsn = $_;
            &verbose( '2',
                "ContextCSN match with SID $serverid: " . $contextcsn );
        }
    }
    unless ($contextcsn) {
        &verbose( '2', "Found no ContextCSN with SID $serverid" );
        return ( '1', "No data" );
    }
    &verbose( '3', "Leave &get_contextCSN" );
    return ( 0, $contextcsn );
}

#=========================================================================
# Main
#=========================================================================

# Options checks
&check_host_param();
&check_warning_param();
&check_critical_param();

my $errorcode;

# Set SID to 000 if not defined
$ldap_serverid ||= "000";

# Connect to the slave
# If $host is an URI, use it directly
my $slave_uri;
if ( $host =~ m#ldap(\+tls)?(s)?://.*# ) {
    $slave_uri = $host;
    $slave_uri .= ":$port" if ( $port and $host !~ m#:(\d)+# );
}
else {
    $slave_uri = "ldap://$host";
    $slave_uri .= ":$port" if $port;
}

my $ldap_slave;
( $errorcode, $ldap_slave ) =
  &get_ldapconn( $slave_uri, $ldap_binddn, $ldap_bindpw );
if ($errorcode) {
    print "Can't connect to $slave_uri.\n";
    exit $ERRORS{'CRITICAL'};
}

# Get the suffix if not provided
if ( !$slave_ldap_suffix ) {
    ( $errorcode, $slave_ldap_suffix ) = &get_suffix($ldap_slave);
    if ($errorcode) {
        print
"Can't get suffix from $slave_uri. Please provide it with -S option.\n";
        exit $ERRORS{'UNKNOWN'};
    }
}

# Get the master URI if not provided
my $master_uri = $ldap_binduri;
if ( !$master_uri ) {
    ( $errorcode, $master_uri ) = &get_masteruri($ldap_slave);
    if ($errorcode) {
        print
"Can't get Master URI from $slave_uri. Please provide it with -U option.\n";
        exit $ERRORS{'UNKNOWN'};
    }
}

# Connect to the master
my $ldap_master;
( $errorcode, $ldap_master ) =
  &get_ldapconn( $master_uri, $ldap_binddn, $ldap_bindpw );
if ($errorcode) {
    print "Can't connect to $master_uri.\n";
    exit $ERRORS{'CRITICAL'};
}

# Get the suffix if not provided
if ( !$master_ldap_suffix ) {
    ( $errorcode, $master_ldap_suffix ) = &get_suffix($ldap_master);
    if ($errorcode) {
        print
"Can't get suffix from $master_uri. Please provide it with -M option.\n";
        exit $ERRORS{'UNKNOWN'};
    }
}

# Get the contextCSN
my $slavecsn;
my $mastercsn;

( $errorcode, $slavecsn ) =
  &get_contextcsn( $ldap_slave, $slave_ldap_suffix, $ldap_serverid );
if ($errorcode) {
    print
"Can't get Context CSN with SID $ldap_serverid from $slave_uri. Please set SID with -I option.\n";
    exit $ERRORS{'UNKNOWN'};
}

( $errorcode, $mastercsn ) =
  &get_contextcsn( $ldap_master, $master_ldap_suffix, $ldap_serverid );
if ($errorcode) {
    print
"Can't get Context CSN with SID $ldap_serverid from $master_uri. Please set SID with -I option.\n";
    exit $ERRORS{'UNKNOWN'};
}

# Compare the utime in CSN
my @slavecsn_elts  = &parse_csn($slavecsn);
my @mastercsn_elts = &parse_csn($mastercsn);
my $time_master = Time::Piece->strptime( $mastercsn_elts[0], "%Y%m%d%H%M%S" );
my $time_slave = Time::Piece->strptime( $slavecsn_elts[0], "%Y%m%d%H%M%S" );
&verbose( '2', "Master times: $time_master" );
&verbose( '2', "Slave times: $time_slave" );
my $utime_master = $time_master->epoch;
my $utime_slave  = $time_slave->epoch;
&verbose( '2', "Master timestamp: $utime_master" );
&verbose( '2', "Slave timestamp: $utime_slave" );
my $deltacsn = abs( $utime_master - $utime_slave );

#==========================================================================
# Exit with Nagios codes
#==========================================================================

# Prepare PerfParse data
my $perfparse = " ";
if ($perf_data) {
    $perfparse = "|'deltatime'=" . $deltacsn . "s;$warning;$critical";
}

# Test the delta and exit
if ( $deltacsn == 0 ) {
    print "OK - directories are in sync (W:$warning - C:$critical)$perfparse";
    exit $ERRORS{'OK'};
}
else {
    if ( $deltacsn < $warning ) {
        print
"OK - directories are not in sync - $deltacsn seconds late (W:$warning - C:$critical)$perfparse";
        exit $ERRORS{'OK'};
    }
    elsif ( $deltacsn > $warning and $deltacsn < $critical ) {
        print
"WARNING - directories are not in sync - $deltacsn seconds late (W:$warning - C:$critical)$perfparse";
        exit $ERRORS{'WARNING'};
    }
    else {
        print
"CRITICAL - directories are not in sync - $deltacsn seconds late (W:$warning - C:$critical)$perfparse";
        exit $ERRORS{'CRITICAL'};
    }
}

exit $ERRORS{'UNKNOWN'};
