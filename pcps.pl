#!/usr/bin/perl
#
# pcps.pl - Postfix Country Policy Service
#
# See the README.md for more info.
#
# Chip Rosenthal
# <chip@unicom.com>
#

use strict;
use warnings;

use Getopt::Std;
use Pod::Usage;
use File::Basename;
use Sys::Syslog qw(:standard :macros);
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Geo::IPfree;
use DB_File;

use constant USAGE => "usage: $0 [-dhtq] [-M ACCESS_MAP] (try \"-h\" for help)\n";

# Path to the access map that is keyed by country. Override with -M.
use constant DEFAULT_ACCESS_MAP => "/etc/postfix/access-country.db";

# Result to return when no policy applies to this address.
# Change this by addding a "default" entry in the access map.
use constant DUNNO => "dunno";

sub show_help {
	print <<\_EOT_;
NAME
	pcps.pl - Postfix Country Policy Service

SYNOPSIS
	perl pcps.pl [OPTION ...]

OPTIONS
	-d    Enable debug logging. Increases syslog logging level from INFO to DEBUG.
	-h    Display this help.
	-q    Log only warnings and errors. Decreases syslog logging level from INFO to NOTICE.
	-t    Also log to stderr. Normally does this if stderr is attached to a tty.
	-M ACCESS_MAP
	      Set path to country access map. Default is /etc/postfix/access-country.db.

	See the package README for further details.

AUTHOR
	Chip Rosenthal
	<chip@unicom.com>

	This package is published at: https://github.com/chip-rosenthal/postfix-country-policy-service

UNLICENSE
	This is free and unencumbered software released into the public domain.
	See https://github.com/chip-rosenthal/postfix-country-policy-service/LICENSE
_EOT_
	exit(0);
}


#
# Parse command line options.
#
my %opts;
if (! getopts('dhqtM:', \%opts)) {
	die USAGE;
}
if ($opts{'h'}) {
	show_help();
}
if (@ARGV != 0 ) {
	die USAGE;
}


#
# Open log.
#
my $logopts = "pid";
if ($opts{'t'} || -t STDERR) {
	$logopts .= ",perror";
}
openlog(basename($0), $logopts, LOG_MAIL);
if ($opts{'d'}) {
	setlogmask(LOG_UPTO(LOG_DEBUG));	# -d enables debug output
} elsif (! $opts{'q'}) {
	setlogmask(LOG_UPTO(LOG_INFO));		# normal logging
} else {
	setlogmask(LOG_UPTO(LOG_NOTICE));	# -q suppresses info output
}


##############################################################################
#
# Functions
#

sub fatal {
	die "usage: fatal MESSAGE" unless (@_ == 1);
	my $mssg = shift;
	syslog(LOG_ERR, "fatal: $mssg");
	exit(1);
}


# Read in a Postfix access policy request.
# It's a block of name=value lines, terminated with blank line.
#
sub load_request {
	die "usage: load_request *FILEHANDLE" unless (@_ == 1);
	local *FH = shift;
	my %attrs;
	while (<FH>) {
		chomp();
		if (! $_) {
			last;
		}
		syslog(LOG_DEBUG, "debug: READ: $_");
		my @a = split(/=/, $_, 2);
		$attrs{$a[0]} = $a[1];
	}
	return %attrs;
}


our $GEO = Geo::IPfree->new;

# Get the two-letter country code for an IP address.
#
sub lookup_country {
	die "usage: lookup_country IP" unless (@_ == 1);
	my($ip) = @_;
	my($code1, $name1) = $GEO->LookUp($ip);
	return $code1;
}


our %DB_ACCESS;
our $ACCESS_MAP = $opts{'M'} || DEFAULT_ACCESS_MAP;
syslog(LOG_DEBUG, "debug: opening access map: $ACCESS_MAP");
tie %DB_ACCESS, 'DB_File', $ACCESS_MAP, O_RDONLY;

# Initially, the default access policy is set to DUNNO.
# This can be overridden by specifying a "default" entry in the access map.
our $DEFAULT_ACCESS = DUNNO;


# Lookup a country in the access map.  The access map keys are two-letter
# country codes (in lower case) with an appended NUL byte.
#
sub lookup_access {
	die "usage: lookup_access COUNTRY" unless (@_ == 1);
	my($country) = @_;
	my $key = lc($country) . "\0";
	return $DB_ACCESS{$key} || $DEFAULT_ACCESS;
}

# Update the default value if one is defined in the access map.
$DEFAULT_ACCESS = lookup_access("default");


# Process a request and determine policy result.
# Returns triple ($client, $country, $result).
#
sub process_request {
	my %attrs = @_;

	my $client = $attrs{'client_address'} || "";
	if (! $client) {
		fatal("client_address not set in input request");
	}
	if (is_ipv6($client)) {
		syslog(LOG_WARNING, "warning: cannot process IPv6: client=$client");
		return ($client, "", $DEFAULT_ACCESS);
	}
	if (! is_ipv4($client)) {
		fatal("invalid IPv4 address: client=$client");
	}

	my $country = lookup_country($client) || "";
	if (! $country) {
		syslog(LOG_WARNING, "warning: country lookup failed: client=$client");
		return ($client, "", $DEFAULT_ACCESS);
	}

	my $result = lookup_access($country);
	return ($client, $country, $result);
}


##############################################################################
#
# Execution
#

my %attrs = load_request(*STDIN);
my($client, $country, $result) = process_request(%attrs);
syslog(LOG_INFO, "info: client=$client country=$country result=$result");
print "action=$result\n\n";

untie %DB_ACCESS;
closelog();
exit(0);
