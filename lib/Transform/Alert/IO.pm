package Transform::Alert::IO;

# VERSION
# ABSTRACT: Base role for Transform::Alert input/output types

use sanity;
use Moo::Role;
use MooX::Types::MooseLike::Base 0.15 qw(Str ArrayRef InstanceOf);

requires qw(open opened close);

has group => (
   is       => 'ro',
   isa      => InstanceOf['Transform::Alert::InputGrp'],
   required => 1,
   weak_ref => 1,
   handles  => [ 'log' ],
);

# Conditional requires
sub get  { die "Dummy get() called!  This method MUST be overloaded!"; }
sub eof  { die "Dummy eof() called!  This method MUST be overloaded!"; }
sub send { die "Dummy send() called!  This method MUST be overloaded!"; }

42;

__END__

=begin wikidoc

= DESCRIPTION
 
This is the role used for all input and output types.

= REQUIRES

All I/O types require the following methods below.  Unless specified, all of
the methods should report a true value on success or undef on error.  The
methods are responsible for their own error logging.

== open

Called on every new interval, if {opened} returns false.  Most types would
open up the connection here and run through any "pre-get/send" setup.  Though,
in the case of UDP, this isn't always necessary.

== opened

Must return a true value if the connection is currently open and valid, or
false otherwise.

Be aware that outputs may potentially have this method called on each alert,
since the group loop will only open the connection if it has something to send.

== get

Inputs only.

Called on each message/alert that is to be parsed through the templates and sent
to the outputs.  This is called on a loop, so the I/O cycle will happen on a
per-alert basis.

This must return a reference to a scalar with the message, or undef on error.

== eof

Inputs only.

Must return a true value if there are no more alerts available to process, or
false otherwise.

== send

Outputs only.

Called on each alert that successfully matched a template.

This is the only method that passes any sort of data, which would be the 
output-rendered string ref, based that the data the input RE-based template
acquired.  The send operation should use these values to send the converted
alert.

== close

Called after the interval loop has been completed.  This should close the
connection and run through any cleanup.

This method should double-check all I/O cleanup with the {opened} method to
ensure that close doesn't fail.  This is important if the loop detects that
the {opened} is false, since it will try a {close} before trying to
re-open.

= PERSISTENT CONNECTIONS

Persistent connections can be done by defining {close} in such a way that it
still keeps the connection online, and making sure {opened} can handle the
state.  Take special care to check that the connection is indeed valid and 
the module can handle re-opens properly.

=end wikidoc
