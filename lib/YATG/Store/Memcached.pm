package YATG::Store::Memcached;

use strict;
use warnings FATAL => 'all';

use Cache::Memcached;

sub store {
    my ($config, undef, $results) = @_;

    die "Must specify list of cache server(s)\n"
        unless ref $config->{cache_memcached}->{servers} eq 'ARRAY'
               and scalar @{$config->{cache_memcached}->{servers}} > 0;

    # get connection to Memcached server
    my $m = eval {
        Cache::Memcached->new( $config->{cache_memcached} )
    } or die "yatg: FATAL: memcached initialization failed: $@\n";

    # results look like this:
    #   $results->{host}->{leaf}->{port} = {value}
    my $TTL = $config->{yatg}->{interval} || 300;

    eval { $m->set('yatg_devices', [keys %$results], $TTL) }
        or warn "yatg: failed to store 'yatg_devices' to memcached\n";

    # send results
    foreach my $device (keys %$results) {
        foreach my $leaf (keys %{$results->{$device}}) {
            eval { $m->set("ports_for:$device",
                [keys %{$results->{$device}->{$leaf}}], $TTL) }
                or warn "yatg: failed to store 'ports_for:$device' to memcached\n";

            foreach my $port (keys %{$results->{$device}->{$leaf}}) {

                (my $key = join ':', $device, $leaf, $port) =~ s/\s/_/g;
                my $val = $results->{$device}->{$leaf}->{$port} || 0;

                if (grep m/^diff$/, @{$config->{yatg}->{oids}->{$leaf}}) {
                    my $oval = $m->get($key) || '0:0';
                    my (undef, $old) = split ':', $oval;
                    $old ||= $val;
                    $val = "$old:$val";
                }

                eval { $m->set($key, $val, $TTL) }
                    or warn "yatg: failed to store '$key' to memcached\n";
            } # port
        } # leaf
    } # device

    return 1;
}

1;

__END__

=head1 NAME

YATG::Store::Disk - Back-end module to store polled data to a Memcached

=head1 DESCRIPTION

This module implements part of a callback handler used to store SNMP data into
a memcached service. It will be faster than storing to disk, and so is
recommended if you do not require historical data.

The module will die if it cannot connect to your memcached server, so see
below for the configuration guidelines. Note that all example keys here use
the namespace prefix of C<yatg:> although this is configurable.

One data structure is passed in which represents a set of results for a set of
polled OIDs on some devices.

In your memcached server, the key C<yatg:yatg_devices> will contain an array
reference containing all device IPs provided in the results data.

Further, each key of the form C<yatg:ports_for:$device> will contain an array
reference containing all ports polled on that device. The port name is not
munged in any way. The "port" entity might in fact just be an index value, or
C<1> if this OID is not Interface Indexed.

Finally, the result of a poll is stored in memcached with a key of the
following format:

 yatg:$device:$leaf:$port

Note that the C<$leaf> is the SNMP leaf name and not the OID. Each value is
stored with a TTL of the polling interval as gathered from the main
C<yatg_updater> configuration. That key will be munged to remove whitespace,
as that is not permitted in memcached keys.

With all this information it is possible to write a script to find all the
data stored in the memcache using the two lookup tables and then retrieving
the desired keys. There is an example of this in the C<examples/> folder of
this distribution, called C<check_interfaces>. It is a Nagios2 check script.

=head1 CONFIGURATION

In the main C<yatg_updater> configuration, you must provide details of the
location of your memcached server. Follow the example (C<yatg.yml>) file in
this distribution. Remember you can override the namespace used, like so:

 cache_memcached:
     namespace: 'my_space'

=head1 SEE ALSO

=over 4

=item L<Cache::Memcached>

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
