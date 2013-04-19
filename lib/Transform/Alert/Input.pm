package Transform::Alert::Input;

# VERSION
# ABSTRACT: Base role for Transform::Alert input types

use sanity;
use Moo::Role;
use MooX::Types::MooseLike::Base qw(HashRef Object);

requires qw(open opened get eof close);

has group => (
   is       => 'rwp',
   isa      => Object,
   weak_ref => 1,
   handles  => [ 'log' ],
);
has connopts => (
   is       => 'ro',
   isa      => HashRef,
   required => 1,
);

42;

__END__

=begin wikidoc

= DESCRIPTION

This is the role used for all input types.

= PROVIDES

== group

The [InputGrp object|Transform::Alert::InputGrp] that constructed it.

== connopts

Hash ref of the connection options (from configuration).

= REQUIRES

All I/O types require the following methods below.  Unless specified, all of the methods should report a true value on success or undef on
error.  The methods are responsible for their own error logging.

== open

Called on every new interval, if {opened} returns false.  Most types would open up the connection here and run through any "pre-get/send" setup.
Though, in the case of UDP, this isn't always necessary.

== opened

Must return a true value if the connection is currently open and valid, or false otherwise.

== get

Called on each message/alert that is to be parsed through the templates and sent to the outputs.  This is called on a loop, so the I/O cycle
will happen on a per-alert basis.

This must return a list of:

   (\$text, $hash)

or undef on error.  The {$text} is used for Template validation, while the {$hash} is stored in the Output/Munger variables as {p}.  See
[Transform::Alert::Input::POP3/OUTPUTS] for an example.

== eof

Must return a true value if there are no more alerts available to process, or false otherwise.

== close

Called after the interval loop has been completed.  This should close the connection and run through any cleanup.

This method should double-check all I/O cleanup with the {opened} method to ensure that close doesn't fail.  This is important if the loop
detects that the {opened} method is false, since it will try a {close} before trying to re-open.

= PERSISTENT CONNECTIONS

Persistent connections can be done by defining {close} in such a way that it still keeps the connection online, and making sure {opened} can
handle the state.  Take special care to check that the connection is indeed valid and the module can handle re-opens properly.

=end wikidoc
