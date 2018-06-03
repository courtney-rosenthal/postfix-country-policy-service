# pcps.pl - Postfix Country Policy Service

The PCPS implements an access policy based on the country of a
remote host.  My use case is to run this policy before greylisting
(http://postgrey.schweikert.ch/), so I can whitelist certain countries
not subject to greylisting.

This service has been tested on Debian Jessie (version 8) Linux.

It uses the GeoIP database that's provided in Debian Linux (and
derivatives such as Ubuntu Linux) as the "geoip-database" package.

Please note that this service is NOT well suited for high volume mail
servers. It has a moderate amount of overhead connecting to the country
and policy databases for each mail delivery. A better design would be
a long-running process that opens the resources once and then serves
requests.


## Installation instructions

### Prerequisites

Besides Postfix, you'll need to install a few support packages.

On Debian Linux, run:

    # apt-get install geoip-database libgeo-ipfree-perl

On Ubuntu Linux, run:

    # apt-get install geoip-database libgeo-ipfree-perl libdata-validate-ip-perl

You can verify the prerequisites by running:

    $ perl pcps.pl -h

You can verify the package is working correctly by running:

    $ cd test
    $ sh run-tests.sh


### Install pcps.pl

Install pcps.pl to /usr/libexec/postfix/pcps.pl

You can do this by running:

    # make install


### Add country-policy service to Postfix

Add the following to your /etc/postfix/master.cf file:

    country-policy unix -   n       n       -       10      spawn
      user=nobody argv=/usr/libexec/postfix/pcps.pl       
  

### Implement country-policy restrictions

Edit your /etc/postfix/main.cf file and modify the
"smtpd_recipient_restrictions" to run the "country-policy" service.

For Postfix version 2.10 and later, you should have your
relay restrictions in "smtpd_relay_restrictions". The
"smtpd_recipient_restrictions" setting contains the additional
restrictions that typically are not applied when authorized
clients use the mail submission (TCP/587) service.

Here is what I use on my system:

    smtpd_relay_restrictions =
        check_recipient_access hash:$config_directory/access,
        permit_tls_clientcerts,
        permit_sasl_authenticated,
        permit_mynetworks,
        reject_unauth_destination

    smtpd_recipient_restrictions =
        # the next line implements access policy by country
        check_policy_service unix:private/country-policy,
        # the next line implements "postgrey" grey listing
        check_policy_service inet:127.0.0.1:10023

The "check_policy_service unix:private/country-policy" line implements
the access policy by country service.

This setup allows me to implement the following policy:

* Senders with a country policy of "OK" are accepted, without running greylisting.

* Senders with a country policy of "REJECT" are rejected, without attempting greylisting.

* Senders that do not have a listed country policy are subject to greylisting.


### Create country access policy map

Created a country access policy map in /etc/postfix/access-country.

The "access-country.example" included with this package illustrates the
format. The "access-country.example" file IS NOT SUITABLE for installation
on a live system.

Some values commonly used are:

* OK - Processing of the restrictions list stops and the message is acepted

* REJECT - Processing of the restrictions list stops and the message is rejected.

* dunno - Processing of the restrictions list continues with the next entry.

Normally, if a country is not specified in the access file the policy will be set to "dunno".
To change this default value, add an entry named "default".

Here is an example access-country file:

    US OK
    CA REJECT

When used with greylisting (as shown in the previous smtpd_recipient_restrictions list), senders
from US will be accepted (without greylisting), senders from CA will be rejected (without greylisting),
and senders from all other countries will be greylisted.

Here is another example:

    default OK
    US dunno

In this example, senders from US will be subject to greylisting, and
senders from all other countries will be accepted without greylisting.


### Hash the access map

Once you've created the countryh access policy map (described above),
hash the map:

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


## Ansible Playbook

The following plays can be used to install this utility using Ansible on a RHEL-like system:

    - name: Download Postfix Country Policy Server
      get_url:
        url: https://raw.githubusercontent.com/chip-rosenthal/postfix-country-policy-service/master/pcps.pl
        dest: /usr/libexec/postfix/pcps.pl
        mode: 0555

    - name: Install Perl cpanm utility
      yum:
        name: perl-App-cpanminus
        state: present

    - name: Install Perl Geo::IPfree module
      cpanm:
        name: Geo::IPfree

    - name: Install Perl Data::Validate::IP module
      cpanm:
        name: Data::Validate::IP

## Author

Chip Rosenthal
<chip@unicom.com>

This package is published at: https://github.com/chip-rosenthal/postfix-country-policy-service

This is free and unencumbered software released into the public domain.
See LICENSE file for full info.

