package RPC::Serialized::Handler::YATG::Store;

use strict;
use warnings FATAL => 'all';

use base 'RPC::Serialized::Handler';
use YATG::Store::Disk;

sub invoke {
    my $self = shift;
    return YATG::Store::Disk::store(@_);
}

1;

__END__

=head1 NAME

RPC::Serialized::Handler::YATG::Store - RPC handler for YATG::Store::Disk

=head1 DESCRIPTION

This module implements an L<RPC::Serialized> handler for L<YATG::Store::Disk>.
There is no special configuration, and all received parameters are passed on
to C<YATG::Store::Disk::store()> verbatim.

=head1 INSTALLATION

You'll need to run an L<RPC::Serialized> server, of course, and configure it
to serve this handler. There are files in the C<examples/> folder of this
distribution to help with that:

=over 4

=item RPC::Serialized configuration, C<server.yml>

 ---
 # configuration for rpc-serialized server with YATG handlers
 rpc_serialized:
     handlers:
         yatg_store:    "RPC::Serialized::Handler::YATG::Store"
         yatg_retrieve: "RPC::Serialized::Handler::YATG::Retrieve"
 net_server:
     port: 1558
     user: daemon
     group: daemon

=back

You should head over to the L<RPC::Serialized> documentation to learn how to
set that up. We use a pre-forking L<Net::Server> based implementation to
receive port traffic data and store to disk, then serve it back out to CGI on
a web server.

=head1 SEE ALSO

=over 4

=item L<RPC::Serialized>

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
