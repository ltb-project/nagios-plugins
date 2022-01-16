#! /usr/bin/perl -w

#==========================================================================
# Summary
#==========================================================================
# Check LDAP query
#
# Request an OpenLDAP monitor backend
#
# Copyright (C) 2010 Clement OUDOT
# Copyright (C) 2010 LTB-project.org
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
use Net::LDAP;

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
my $type;
my $type_string;
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
my $ldap_base;
my $ldap_filter;
my $ldap_scope;
my $ldap_attribute;

GetOptions(
    'h'          => \$help,
    'help'       => \$help,
    'V'          => \$version,
    'version'    => \$version,
    'v+'         => \$verbose,
    'verbose+'   => \$verbose,
    'H:s'        => \$host,
    'host:s'     => \$host,
    'w:i'        => \$warning,
    'warning:i'  => \$warning,
    'c:i'        => \$critical,
    'critical:i' => \$critical,
    'm:s'        => \$mode,
    'mode:s'     => \$mode,
    'T:s'        => \$type,
    'type:s'     => \$type,

    #'l:s'=> \$logname,'logname:s'=> \$logname,
    #'a:s'=> \$authentication,
    #'authentication:s'=> \$authentication,
    #'F:s'=> \$log_file,'log_file:s'=> \$log_file,
    'f'         => \$perf_data,
    'perf_data' => \$perf_data,

    #'n:s'       => \$name,
    #'name:s'    => \$name,
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
    'D:s'      => \$ldap_binddn,
    'binddn:s' => \$ldap_binddn,
    'P:s'      => \$ldap_bindpw,
    'bindpw:s' => \$ldap_bindpw,
    'b:s'      => \$ldap_base,
    'base:s'   => \$ldap_base,
    's:s'      => \$ldap_scope,
    'scope:s'  => \$ldap_scope,
    'F:s'      => \$ldap_filter,
    'filter:s' => \$ldap_filter,
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

    print "\n\nRequest OpenLDAP Monitor backend.\n\n";

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
    print "-w, --warning=INTERGER\n";
    print "\tNumber limit to return a warning status.\n";
    print "-c, --critical=DOUBLE\n";
    print "\tNumber limit to return a critical status.\n";
    print "-m --mode=(greater|lesser)\n";
    print
"\tDefine if number returned should be greater or lesser thant thresold\n";
    print "-T --type=STRING\n";
    print "\tDefine which information to check:\n";
    print "\t\tcurrentconnections: current established connections\n";
    print "\t\ttotalconnections: total established connections\n";
    print "\t\tdncache: total DN in cache\n";
    print "\t\tentrycache: total entries in cache\n";
    print "\t\tidlcache: total IDL in cache\n";
    print "\t\ttotaloperations: total operations\n";
    print "\t\ttotalabandon: total ABANDON operations\n";
    print "\t\ttotaladd: total ADD operations\n";
    print "\t\ttotalbind: total BIND operations\n";
    print "\t\ttotalcompare: total COMPARE operations\n";
    print "\t\ttotaldelete: total DELETE operations\n";
    print "\t\ttotalextended: total EXTENDED operations\n";
    print "\t\ttotalmodify: total MODIFY operations\n";
    print "\t\ttotalmodrdn: total MODRDN operations\n";
    print "\t\ttotalsearch: total SEARCH operations\n";
    print "\t\ttotalunbind: total UNBIND operations\n";
    print "\t\tmdbpagesmax: maximum pages in MDB database\n";
    print "\t\tmdbpagesused: used pages in MDB database\n";
    print "\t\tmdbpagesfree: free pages in MDB database\n";
    print "\t\tmdbpagesusedrelative: percent of used pages in MDB database\n";
    print "\t\tmdbpagesfreerelative: percent of free pages in MDB database\n";

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
    print "\tBind DN. Bind anonymous if not present.\n";
    print "-P, --bindpw=STRING\n";
    print "\tBind passwd. Need the Bind DN option to work.\n";
    print "-F, --filter=STRING\n";
    print "\tLDAP search filter.\n";
    print "-b, --base=STRING\n";
    print "\tLDAP search base.\n";
    print "-s, --scope=STRING\n";
    print "\tLDAP search scope\n";
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

# check if -b is used
sub check_base_param {
    if ( !defined($ldap_base) ) {
        printf "UNKNOWN: you have to define a search base.\n";
        exit $ERRORS{UNKNOWN};
    }
}

# check if -t is correctly used
sub check_type {
    if ( !defined($type) ) {
        printf "UNKNOWN: you have to define a type\n";
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

    if ( $mode eq "lesser" and $critical >= $warning ) {
        printf "With lesser mode, warning should be greater than critical\n";
        exit $ERRORS{UNKNOWN};
    }
    elsif ( $mode eq "greater" and $warning >= $critical ) {
        printf "With greater mode, warning should be lesser than critical\n";
        exit $ERRORS{UNKNOWN};
    }
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
        my %h       = split( /[&=]/, $tlsParam );
        my $message = $ldap->start_tls(%h);
        $message->code
          && &verbose( '1', $message->error )
          && return ( $message->code, $message->error );
        &verbose( '2', "startTLS succeed on $server" );
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
        &verbose( '2', "Bind anonym" );
    }
    &verbose( '3', "Leave &get_ldapconn" );
    return ( '0', $ldap );
}

sub get_value {
    &verbose( '3', "Enter &get_value" );
    my ( $ldapconn, $base, $scope, $filter, $attribute ) = @_;
    my $message;
    my $entry;
    my $attrs = ref($attribute) eq 'ARRAY' ? $attribute : [$attribute];
    $message = $ldapconn->search(
        base   => $base,
        scope  => $scope,
        filter => $filter,
        attrs  => $attrs
    );
    $message->code
      && &verbose( '1', $message->error )
      && return ( $message->code, $message->error );
    if ( $entry = $message->shift_entry() ) {
        my @result = ();
        for (@$attrs) {
            my $val = $entry->get_value($_);
            unless ($val) {
                &verbose( 1, "Attribute $_ not found in " . $entry->dn );
                return ( 1, "Attribute $_ not found" );
            }
            push(@result, $val);
        }
        &verbose( '2', "Found value @result" );
        &verbose( '3', "Leave &get_value" );
        return (0, @result == 1 ? $result[0] : $result[0] * 100 / $result[1]);
    }
    else {
        return ( '1', "No entry found" );
    }
}

#=========================================================================
# Main
#=========================================================================

# Default values
$mode ||= "lesser";

# Options checks
&check_host_param();
&check_type();
&check_warning_param();
&check_critical_param();

my $errorcode;

# Connect to the directory
# If $host is an URI, use it directly
my $ldap_uri;
if ( $host =~ m#ldap(\+tls)?(s)?://.*# ) {
    $ldap_uri = $host;
    $ldap_uri .= ":$port" if ( $port and $host !~ m#:(\d)+# );
}
else {
    $ldap_uri = "ldap://$host";
    $ldap_uri .= ":$port" if $port;
}

my $ldap_server;
( $errorcode, $ldap_server ) =
  &get_ldapconn( $ldap_uri, $ldap_binddn, $ldap_bindpw );
if ($errorcode) {
    print "Can't connect to $ldap_uri.\n";
    exit $ERRORS{'UNKNOWN'};
}

# Convert type into Monitor LDAP parameters
my $type_defined = 0;
if ( $type =~ /currentconnections/i ) {
    $type_string = "current connections";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Current,cn=Connections,cn=Monitor";
    $ldap_attribute = "monitorCounter";
    $type_defined   = 1;
}
if ( $type =~ /totalconnections/i ) {
    $type_string = "total connections";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Total,cn=Connections,cn=Monitor";
    $ldap_attribute = "monitorCounter";
    $type_defined   = 1;
}
if ( $type =~ /dncache/i ) {
    $type_string = "DN in cache";
    $ldap_filter ||= "(objectClass=olmBDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = "olmBDBDNCache";
    $type_defined   = 1;
}
if ( $type =~ /entrycache/i ) {
    $type_string = "entries in cache";
    $ldap_filter ||= "(objectClass=olmBDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = "olmBDBEntryCache";
    $type_defined   = 1;
}
if ( $type =~ /idlcache/i ) {
    $type_string = "IDL in cache";
    $ldap_filter ||= "(objectClass=olmBDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = "olmBDBIDLCache";
    $type_defined   = 1;
}
if ( $type =~ /totaloperations/i ) {
    $type_string = "total operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalabandon/i ) {
    $type_string = "total ABANDON operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Abandon,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totaladd/i ) {
    $type_string = "total ADD operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Add,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalbind/i ) {
    $type_string = "total BIND operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Bind,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalcompare/i ) {
    $type_string = "total COMPARE operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Compare,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totaldelete/i ) {
    $type_string = "total DELETE operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Delete,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalextended/i ) {
    $type_string = "total EXTENDED operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Extended,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalmodify/i ) {
    $type_string = "total MODIFY operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Modify,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalmodrdn/i ) {
    $type_string = "total MODRDN operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Modrdn,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalsearch/i ) {
    $type_string = "total SEARCH operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Search,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /totalunbind/i ) {
    $type_string = "total UNBIND operations";
    $ldap_filter ||= "(objectClass=*)";
    $ldap_scope  ||= "base";
    $ldap_base   ||= "cn=Unbind,cn=Operations,cn=Monitor";
    $ldap_attribute = "monitorOpCompleted";
    $type_defined   = 1;
}
if ( $type =~ /mdbpagesmax/i ) {
    $type_string = "maximum pages in MDB database";
    $ldap_filter ||= "(objectClass=olmMDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = "olmMDBPagesMax";
    $type_defined   = 1;
}
if ( $type =~ /mdbpagesused/i ) {
    $type_string = "used pages in MDB database";
    $ldap_filter ||= "(objectClass=olmMDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = "olmMDBPagesUsed";
    $type_defined   = 1;
}
if ( $type =~ /mdbpagesfree/i ) {
    $type_string = "free pages in MDB database";
    $ldap_filter ||= "(objectClass=olmMDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = "olmMDBPagesFree";
    $type_defined   = 1;
}

if ( $type =~ /mdbpagesusedrelative/i ) {
    $type_string = "percent of used pages in MDB database";
    $ldap_filter ||= "(objectClass=olmMDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = ["olmMDBPagesUsed", "olmMDBPagesMax"];
    $type_defined   = 1;
}

if ( $type =~ /mdbpagesfreerelative/i ) {
    $type_string = "percent of free pages in MDB database";
    $ldap_filter ||= "(objectClass=olmMDBDatabase)";
    $ldap_scope  ||= "one";
    $ldap_base   ||= "cn=Databases,cn=Monitor";
    $ldap_attribute = ["olmMDBPagesFree", "olmMDBPagesMax"];
    $type_defined   = 1;
}

unless ($type_defined) {
    print "Type $type is not known.\n";
    exit $ERRORS{'UNKNOWN'};
}

# Request LDAP
my $value;
( $errorcode, $value ) =
  &get_value( $ldap_server, $ldap_base, $ldap_scope, $ldap_filter,
    $ldap_attribute );
if ($errorcode) {
    print "LDAP search failed: $value.\n";
    exit $ERRORS{'UNKNOWN'};
}

#==========================================================================
# Exit with Nagios codes
#==========================================================================

# Prepare PerfParse data
my $perfparse = " ";
if ($perf_data) {
    $perfparse = "|'$type'=" . $value . ";$warning;$critical";
}

# Test value and exit
if ( $mode eq "greater" ) {
    if ( $value < $warning ) {
        print "OK - $value $type_string returned $perfparse\n";
        exit $ERRORS{'OK'};
    }
    elsif ( $value >= $warning and $value < $critical ) {
        print "WARNING - $value $type_string returned $perfparse\n";
        exit $ERRORS{'WARNING'};
    }
    else {
        print "CRITICAL - $value $type_string returned $perfparse\n";
        exit $ERRORS{'CRITICAL'};
    }
}
elsif ( $mode eq "lesser" ) {
    if ( $value > $warning ) {
        print "OK - $value $type_string returned $perfparse\n";
        exit $ERRORS{'OK'};
    }
    elsif ( $value <= $warning and $value > $critical ) {
        print "WARNING - $value $type_string returned $perfparse\n";
        exit $ERRORS{'WARNING'};
    }
    else {
        print "CRITICAL - $value $type_string returned $perfparse\n";
        exit $ERRORS{'CRITICAL'};
    }
}

exit $ERRORS{'UNKNOWN'};

