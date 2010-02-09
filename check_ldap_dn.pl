#!/usr/bin/perl -w

#====================================================================
# What's this ?
#====================================================================
# Script designed for Nagios ( http://www.nagios.org )
# Checks if a DN is in an LDAP Server
# Returns Nagios Code
#
# Copyright (C) 2004 Clement OUDOT
# Copyright (C) 2009 LTB-project.org
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#====================================================================

#====================================================================
# Packages
#====================================================================
use strict;
use Net::LDAP;
use Getopt::Std;

#====================================================================
# Global parameters
#====================================================================
my %code = ( Ok => 0, Warning => 1, Critical => 2, Unknown => 3 );
my ( $host, $port, $binddn, $bindpw, $dn ) = &options;
my $timeout = 5;
my $version = 3;

#====================================================================
# Main program
#====================================================================

main();

sub main {

    # LDAP Connection

    my $ldap = Net::LDAP->new(
        $host,
        port    => $port,
        version => $version,
        timeout => $timeout
    );

    unless ($ldap) {
        print "LDAP Critical : Pb with LDAP connection\n";
        exit $code{Critical};
    }

    # Bind

    if ( $binddn && $bindpw ) {

        # Bind witch credentials

        my $req_bind = $ldap->bind( $binddn, password => $bindpw );

        if ( $req_bind->code ) {
            print "LDAP Unknown : Bind Error "
              . $req_bind->code . " : "
              . $req_bind->error . "\n";
            exit $code{Unknown};
        }
    }

    else {

        # Bind anonymous

        my $req_bind = $ldap->bind();

        if ( $req_bind->code ) {
            print "LDAP Unknown : Bind Error "
              . $req_bind->code . " : "
              . $req_bind->error . "\n";
            exit $code{Unknown};
        }
    }

    # Base Search

    my $req_search = $ldap->search(
        base   => $dn,
        scope  => 'base',
        filter => 'objectClass=*',
        attrs  => ['1.1']
    );

    if ( $req_search->code == 32 ) {

        # No such object Error
        print "LDAP Critical : $dn not present\n";
        $ldap->unbind();
        exit $code{Critical};
    }

    elsif ( $req_search->code ) {
        print "LDAP Unknown : Search Error "
          . $req_search->code . " : "
          . $req_search->error . "\n";
        $ldap->unbind();
        exit $code{Unknown};
    }

    else {
        print "LDAP OK : $dn is present\n";
        $ldap->unbind();
        exit $code{Ok};
    }

}

sub options {

    # Get and check args
    my %opts;
    getopt( 'HpDWb', \%opts );
    &usage unless ( exists( $opts{"H"} ) );
    &usage unless ( exists( $opts{"b"} ) );
    $opts{"p"} = 389 unless ( exists( $opts{"p"} ) );
    $opts{"D"} = 0   unless ( exists( $opts{"D"} ) );
    $opts{"w"} = 0   unless ( exists( $opts{"W"} ) );
    return ( $opts{"H"}, $opts{"p"}, $opts{"D"}, $opts{"W"}, $opts{"b"} );
}

sub usage {

    # Print Help/Error message
    print
"LDAP Unknown : Usage :\n$0 -H hostname [-p port] [-D binddn -W bindpw] -b dn\n";
    exit $code{Unknown};
}
