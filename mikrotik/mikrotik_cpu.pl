#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: mikrotik_cpu.pl
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Heince Kurniawan
#       EMAIL : heince.kurniawan@itgroupinc.asia
# ORGANIZATION: IT Group Indonesia
#      VERSION: 1.0
#      CREATED: 02/02/17 16:36:24
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Carp;
use v5.10.1;
use Net::SNMP;
use Monitoring::Plugin;

#-------------------------------------------------------------------------------
#  default 
#-------------------------------------------------------------------------------
my $version         = 0.1;
my $warning         = 70;
my $critical        = 80;
my $CPUOID          = ".1.3.6.1.2.1.25.3.3.1.2.1";
my $SNMPCommunity   = "public";
my $SNMPPort        = "161";

my $np = Monitoring::Plugin->new(
            usage => "Usage: %s [ -v|--verbose  ]  [-H <host>] [-t <timeout>] "
            . "[ -c|--critical=<threshold>  ] [ -w|--warning=<threshold>  ]",
            version     => $version,
);

$np->add_arg(
            spec => 'warning|w=i',
            help => '-w, --warning=INTEGER:INTEGER ' . "Default is $warning, See "
            . 'https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT '
            . 'for the threshold format. ',
);

$np->add_arg(
            spec => 'critical|c=i',
            help => '-c, --critical=INTEGER:INTEGER ' . "Default is $critical, See "
            . 'https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT '
            . 'for the threshold format. ',
);

$np->add_arg(
            spec => 'hostname|H=s',
            help => '-H, --hostname=ADDRESS',
);

$np->getopts;

#-------------------------------------------------------------------------------
#  sanity check or die
#-------------------------------------------------------------------------------
unless (defined $np->opts->hostname)
{
    $np->plugin_die("hostname not defined");
}

#-------------------------------------------------------------------------------
#  check if defined if not set with default value
#-------------------------------------------------------------------------------
if (defined $np->opts->warning)
{
    print "warning: " . $np->opts->warning . "\n" if $np->opts->verbose;
}
else
{
    print "using default warning: $warning\n" if $np->opts->verbose;
}

if (defined $np->opts->critical)
{
    print "critical: " . $np->opts->critical . "\n" if $np->opts->verbose;
}
else
{
    print "using default critical: $critical\n" if $np->opts->verbose;
}

if (my $result = retrieve_cpu($np->opts->hostname))
{
    $np->set_thresholds(
        warning     => $np->opts->warning   //   $warning,
        critical    => $np->opts->critical  //   $critical,
    );

    $np->add_perfdata(
                        label   => "cpu usage",
                        value   => $result,
                        uom     => '%',
    );

    my $code = $np->check_threshold(check => $result);

    if ($code != OK)
    {
        $np->plugin_exit( $code, "CPU Usage above Threshold"  );
    }
    elsif ($code == OK)
    {
        $np->plugin_exit( $code, "Usage $result" . '%' );
    }
    else
    {
        $np->plugin_exit( $code, "CPU Usage UNKNOWN" );
    }

=comment
    $np->plugin_exit(
        return_code => $np->check_threshold($result),
        message     => " sample result was $result"
    );
=cut
}
else
{
    $np->plugin_exit( CRITICAL, "could not retrieve cpu usage" );
}

sub retrieve_cpu
{
    my $host = shift;
    my $result;

    my ($Session, $Error) = Net::SNMP->session (
                                            -hostname  => $host,
                                            -community => $SNMPCommunity,
                                            -port      => $SNMPPort,
                                            -timeout   => 60,
                                            -retries   => 5,
                                            -version   => 1);
    if (!defined($Session)) {
      die "Croaking: $Error";
    }

    if ($result = $Session->get_request(-varbindlist => [$CPUOID])) {
        print "Result: " . $result->{$CPUOID} . "\n" if $np->opts->verbose;
        $Session->close;
    }
    else
    {
        $Session->close;
        return 0;
    }

    return $result->{$CPUOID};
}
