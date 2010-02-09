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
# GPL Licence : http://www.gnu.org/licenses/gpl.txt
#====================================================================

#====================================================================
# Packages
#====================================================================
use strict;
use Net::LDAP;
use Getopt::Std;
use Time::HiRes qw(gettimeofday);

#====================================================================
# Global parameters
#====================================================================
my $version = 3;
my %code = ( Ok => 0, Warning => 1, Critical => 2, Unknown => 3 );
my ( $host, $port, $binddn, $bindpw, $nb_threads, $warning, $critical ) =
  &options;

#====================================================================
# Main program
#====================================================================

main();

sub main {

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

    # Nagios result

    if ( $time < $warning ) {
        print "LDAP Ok : $time second response time on port $port\n";
        exit $code{Ok};
    }
    elsif ( $time < $critical ) {
        print "LDAP Warning : $time second response time on port $port\n";
        exit $code{Warning};
    }
    else {
        print "LDAP Critical : $time second response time on port $port\n";
        exit $code{Critical};
    }
}

sub test_ldap {

    # Start timer

    my $start_time = gettimeofday();

    # LDAP Connection

    my $ldap = Net::LDAP->new(
        $host,
        port    => $port,
        version => $version,
        timeout => $critical
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
        base   => '',
        scope  => 'base',
        filter => 'objectClass=*',
        attrs  => ['1.1']
    );

    if ( $req_search->code ) {
        print "LDAP Unknown : Search Error "
          . $req_search->code . " : "
          . $req_search->error . "\n";
        $ldap->unbind;
        exit $code{Unknown};
    }

    # Unbind

    $ldap->unbind();

    # Stop Timer

    my $end_time = gettimeofday();

    my $time = $end_time - $start_time;

    # Return $time

    return $time;
}

sub options {

    # Get and check args
    my %opts;
    getopt( 'HpiDWnwc', \%opts );
    &usage unless ( exists( $opts{"H"} ) );
    $opts{"p"} = 389 unless ( exists( $opts{"p"} ) );
    $opts{"D"} = 0   unless ( exists( $opts{"D"} ) );
    $opts{"W"} = 0   unless ( exists( $opts{"W"} ) );
    $opts{"n"} = 0   unless ( exists( $opts{"n"} ) );
    $opts{"w"} = 20  unless ( exists( $opts{"w"} ) );
    $opts{"c"} = 60  unless ( exists( $opts{"c"} ) );
    return (
        $opts{"H"}, $opts{"p"}, $opts{"D"}, $opts{"W"},
        $opts{"n"}, $opts{"w"}, $opts{"c"}
    );
}

sub usage {

    # Print Help/Error message
    print
"LDAP Unknown : Usage :\n$0 -H hostname [-p port] [-D binddn -W bindpw] [-n nb_threads] [-w warning_time] [-c critical_time])\n";
    exit $code{Unknown};
}
