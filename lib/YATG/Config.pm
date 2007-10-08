package YATG::Config;

use strict;
use warnings FATAL => 'all';

use Module::MultiConf 0.0301;

__PACKAGE__->Validate({
    yatg => {
        oids         => { type => HASHREF },
        dbi_connect  => { type => ARRAYREF },
        dbi_ip_query => { type => SCALAR, default =>
'SELECT ip FROM device WHERE extract(epoch from last_macsuck) > (extract(epoch from now()) - 7200)' },
        interval     => { type => SCALAR, default => 300 },
        timeout      => { type => SCALAR, default => 280 },
        max_pollers  => { type => SCALAR, default => 20  },
        debug        => { type => SCALAR, default => 0   },
        communities  => { type => SCALAR | ARRAYREF,
                                          default => 'public' },
        mibdirs      => { type => ARRAYREF, default => [qw(
            /usr/share/netdisco/mibs/cisco
            /usr/share/netdisco/mibs/rfc
            /usr/share/netdisco/mibs/net-snmp
        )] },
        disk_root    => { type => SCALAR, default => '/var/lib/yatg' },
    },
    cache_memcached => {
        servers   => { type => ARRAYREF, optional => 1 },
        namespace => { type => SCALAR, default => 'yatg:' },
    },
    rpc_serialized_client_inet => {
        data_serializer => { type => HASHREF,
                             default => {serializer => 'YAML::Syck'} },
        io_socket_inet  => { type => HASHREF, optional => 1 },
    },
    log_dispatch_syslog => {
        name      => { type => SCALAR, default => 'yatg' },
        ident     => { type => SCALAR, default => 'yatg' },
        min_level => { type => SCALAR, default => 'info' },
        facility  => { type => SCALAR, default => 'local1' },
        callbacks => { type => CODEREF | ARRAYREF,
                            default => sub { return "$_[1]\n" } },
    },
});

1;

__END__

=head1 NAME

YATG::Config - Configuration management for YATG

=head1 REQUIRED CONFIGURATION

C<yatg_updater> expects one command line argument, which is its main
configuration file. This must be in a format recognizable to L<Config::Any>,
and you must use a file name suffix to give that module a hint.

There is a fairly complete example of this configuration file in the
C<examples/> folder of this distribution - look for the C<yatg.yml> file. The
file must parse out to an anonymous hash of hashes, as in the example.

Let's first consider the C<yatg> key/value, which is the main configuration
area.

=head2 C<oids>

Again this is a hash, with keys being the Leaf Name of an SNMP OID. This tells
C<yatg_updater> the list of OIDs which you would like gathering from each
network device. The value for each leaf name key is a list of magic words
which tell C<yatg_updater> whether to get the OID, and what to do with the
results. Some of the magic words are mutually exclusive.

 # example key and "magic words" value
 ifOperStatus: [disk, ifindex]

=head3 Storage

These are the storage methods for the resuls, and an OID without one of these
magic words will be ignored. You should only specify one of these for each
leaf name.

=over 4

=item C<stdout>

This means to use the L<Data::Dumper> to print results.  It's good for
testing.

=item C<disk>

Disk storage means to create a file for each OID of each port on each device.
It is very fast and efficient by design, and most useful for long-term
historical data such as port traffic counters. For more information on disk
storage, see L<YATG::Store::Disk>.

=item C<memcached>

If you don't need data history, then this module is a better alternative than
disk-based storage, because of its speed. A memcached server is required of
course. For more information see L<YATG::Store::Memcached>.

=item C<rpc>

This is merely an extension to the C<disk> storage module which allows
C<yatg_updater> to use disk on another machine. You can think of it as an
RPC-based alternative to network mounting of a filesystem. On the remote host,
the C<disk> module is still used for storage. See L<YATG::Store::RPC> for more
details.

=back

=head3 Interface Indexed OIDs

Although C<yatg_updater> will happily poll single value or plain indexed OIDs,
you can give it a hint that there is an interface-indexed OID in use.

In that case, C<yatg_updater> will make sure  that C<IfDescr> and
C<IfAdminStatus> are retrieved from the device, and results will be keyed by
human-friendly names (e.g. C<FastEthernet2/1>) rather than SNMP interface
indexes (e.g. C<10101>).

Being indexed by interface is something C<yatg_updater> cannot work out for
itself for an OID, so provide the C<ifindex> magic word to enable this
feature.

=head3 IP address filtering

We have not yet covered how C<yatg_updater> obtains its list of devices to
poll, but for now all you need to know is that by default all listed leaf
names will be polled on all devices.

You can however provide magic words to override this behaviour and reduce the
device space to be polled for a leaf name. Each of these magic words may
appear more than once:

=over 4

=item C<< 192.2.1.10 >> or C<192.1.1.0/24>

Any IP address or IP subnet in these forms will be taken as a restriction
placed upon the cached list of device IPs. If the IP is not in the cached list
already, then it will not be polled. As soon as you use a magic word like
this, then IPs in the cached list not mentioned explicity will also be
excluded from a poll on this leaf name.

In case it is not clear, an IP address and a subnet are no different - a
C</32> subnet mask is assumed in the case of an IP address.

=item C<!192.2.1.10> or C<!192.1.1.0/24>

Using an exclamation mark at the head of the IP address introduces an
exclusion filter upon the cached list of IP addresses. This will override an
explicit mention of an address (such as in the note, above). These IP
addresses will then not be polled for the associated leaf name.

In case it is not clear, an IP address and a subnet are no different - a
C</32> subnet mask is assumed in the case of an IP address.

=back

=head2 C<communities>

Provide a list of SNMP community strings to the system using this parameter.
For each device, at startup, C<yatg_updater> will work out which community to
use and cache that for subsequent SNMP polling. For example:

 communities: [public, anotherone]

=head2 C<dbi_connect> and the list of devices

At start-up, C<yatg_updater> needs to be given a list of device IPs which it
should poll with SNMP. We designed this system to work with NetDisco (a
network management system) which populates a back-end database with device
IPs. C<yatg_updater> will make a connection to a database and gather IPs.

By default the SQL query is set for use with NetDisco, so if you use that
system you only need alter the DBI connection parameters (password, etc) in
the C<dbi_connect> value in the example configuration file.

If you want to use a different SQL query, add a new key and value to the
configuration like so (this is an example, of course!):

 dbi_ip_query: 'select ip from device;'

The query must return a single list of IPs. If you don't have a back-end
database with such information, then install SQLite and quickly set one up.
It's good practice for asset management, if nothing else.

=head2 C<mibdirs>

If you use NetDisco, and have the MIB files from that distribution installed
in C</usr/share/netdisco/mibs/...> then you can probably ignore this as the
default will work.

Otherwise, you must provide this application with all the MIBs required to
translate leaf names to OIDs and get data types for polled values. This key
takes a list of directories on your system which contain MIB files. They will
all be loaded when C<yatg_updater> starts, so only specify what you need
otherwise that will take a long time. Also make sure all references in the
MIBs are resolvable to other MIBs. There is a bug in the current release of
NetDisco MIBs as it is missing two MIB files.

Here is an example in YAML:

 mibdirs:
     ['/usr/share/netdisco/mibs/cisco',
      '/usr/share/netdisco/mibs/rfc',
      '/usr/share/netdisco/mibs/net-snmp']

=head1 OPTIONAL CONFIGURATION

There are some additional, optional keys for the C<oids> section:

=over 4

=item C<interval>

C<yatg_updater> polls all devices at a given interval. Provide a number of
settings to this key if you want to override the default of 300 (5 minutes).

=item C<timeout>

If the poller does not return data from all devices within C<timeout> seconds,
then the application will die. The default is 280. You should always have a
little head-room between the C<timeout> and C<interval>.

=item C<max_pollers>

This system uses C<SNMP::Effective> for the SNMP polling, which is a fast,
lightweight wrapper to the C<SNMP> perl libraries. C<SNMP::Effective> polls
asynchronously and you can set the maximum number of polls which are happening
at once using this key. The default is 20 which is reasonably for any modern
computer.

=item C<debug>

If this key has a true value, C<yatg_updater> will print out various messages
on standard output, instead of using a log file. It's handy for testing, and
defaults to false of course.

=back

=head1 LOGGING CONFIGURATION

This module uses C<Log::Dispatch::Syslog> for logging, and by default will log
timing data to your system's syslog service. The following parameters can be
overridden in a section at the same level as C<oids>, but called
C<log_dispatch_syslog>:

=over 4

=item C<name> and C<ident>

These are the tokens used to identify the process to syslog, and both default
to C<yatg>.

=item C<min_level>

By default the logging level will be C<info> so override this to change that.

=item C<facility>

By default the syslog facility will be C<local1> so override this to change
that.

=back

Here is an example of what you might do:

 log_dispatch_syslog:
     name:       'my_app'
     ident:      'my_app'
     min_level:  'warning'
     facility:   'local4'

=head1 SEE ALSO

=over 4

=item L<http://www.netdisco.org/>

=item L<http://www.sqlite.org/>

=back

=head1 AUTHOR

Oliver Gorwits C<< <oliver.gorwits@oucs.ox.ac.uk> >>

=head1 COPYRIGHT & LICENSE

Copyright (c) The University of Oxford 2007. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
St, Fifth Floor, Boston, MA 02110-1301 USA

=cut
