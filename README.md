# pcps.pl - Postfix Country Policy Service

The PCPS implements an access policy based on the country of a
remote host.  My use case is to run this policy before greylisting
(http://postgrey.schweikert.ch/), so I can whitelist certain countries
not subject to greylisting.

This service has been tested on Debian Jessie (version 8) Linux.

Please note that this service is NOT well suited for high volume mail
servers. It has a moderate amount of overhead connecting to the country
and policy databases for each mail delivery. A better design would be
a long-running process that opens the resources once and then serves
requests.


## Installation instructions

### Prerequisites

Besides Postfix, you'll need to install a few support packages. Run:

    # apt-get install geoip-database libgeo-ipfree-perl

You can verify your environment by running:

    $ cd test
    $ sh run-tests.sh


### Install pcps.pl

Install pcps.pl to /usr/lib/postfix/pcps.pl

You can do this by running:

    # make install


### Add country-policy service to Postfix

Add the following to your /etc/postfix/master.cf file:

    country-policy unix -   n       n       -       10      spawn
      user=nobody argv=/usr/lib/postfix/pcps.pl       
  

### Implement country-policy restrictions

Edit your /etc/postfix/main.cf file and modify the
"smtpd_recipient_restrictions" similar to the following:

    smtpd_recipient_restrictions =
	check_recipient_access hash:$config_directory/access,
	permit_tls_clientcerts,
	permit_sasl_authenticated,
	permit_mynetworks,
	reject_unauth_destination,
        check_policy_service unix:private/country-policy, <<< ADDED
        check_policy_service inet:127.0.0.1:10023

In this example, the marked line was added to implement the
country access policy.

It is important that you have a "reject_unauth_destination" entry
BEFORE the country access policy entry.

The "check_policy_service inet:127.0.0.1:10023" entry is for
the "postgrey" service as implemented on Debian.

What this example does:

    * Senders with a country policy of "OK" are accepted, without running greylisting.

    * Senders with a country policy of "REJECT" are rejected, before attempting greylisting.

    * Senders with a country policy of "dunno" are subject to greylisting.

    * The default policy for a country not listed is "dunno".


### Create country access policy map

Created a country access policy map in /etc/postfix/access-country.

The "access-country.example" included with this package illustrates the
format. The "access-country.example" file IS NOT SUITABLE for installation
on a live system.

When you are done, hash the map:

    $ sudo postmap /etc/postfix/access-country


### Reload Postfix system

Finally, reload the Postfix:

    $ sudo systemctl reload postfix.service

Ensure the system reloaded without error:

    $ sudo tail /var/log/mail.log
        .
        .
        .
    Nov 20 12:26:52 redshirt postfix/master[1582]: reload -- version 2.11.3, configuration /etc/postfix


## Debugging

If there are problems, check your /var/log/mail.log for errors.

You can enable debug logging by modifying your "/etc/postfix/master.cf" file
and adding "-v" to the end of the pcps.pl command line. Be sure to reload
postfix.service after doing this.


## Author

Chip Rosenthal
<chip@unicom.com>

This package is published at: https://github.com/chip-rosenthal/postfix-country-policy-service

