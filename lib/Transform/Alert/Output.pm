package Transform::Alert::Output;

# VERSION
# ABSTRACT: Base role for Transform::Alert output types

use sanity;
use Moo::Role;
use MooX::Types::MooseLike::Base qw(Str ScalarRef HashRef Object);

use File::Slurp 'read_file';

requires qw(open opened send close);

around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   # read template file
   if (my $tmpl_file = delete $hash->{templatefile}) { $hash->{template} = read_file($tmpl_file); }

   # work with inline templates (and file above)
   if (exists $hash->{template} && not ref $hash->{template}) {
      my $tmpl_text = $hash->{template};
      $tmpl_text =~ s/^\s+|\s+$//g;  # remove leading/trailing spaces
      $hash->{template} = \$tmpl_text;
   }

   $orig->($self, $hash);
};

has daemon => (
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
has template => (
   is       => 'ro',
   isa      => ScalarRef[Str],
   required => 1,
);

42;

__END__

=begin wikidoc

= DESCRIPTION

This is the role used for all output types.

= PROVIDES

== daemon

The [Alert object|Transform::Alert] that constructed it.

== connopts

Hash ref of the connection options (from configuration).

== template

Scalar ref of the output template.

= REQUIRES

All I/O types require the following methods below.  Unless specified, all of the methods should report a true value on success or undef on
error.  The methods are responsible for their own error logging.

== open

Called on every new interval, if {opened} returns false.  Most types would open up the connection here and run through any "pre-get/send" setup.
Though, in the case of UDP, this isn't always necessary.

== opened

Must return a true value if the connection is currently open and valid, or false otherwise.

Be aware that outputs may potentially have this method called on each alert, since the group loop will only open the connection if it has
something to send.

== send

Called on each alert that successfully matched a Template and/or Munger.

This is the only method that passes any sort of data, which would be the output-rendered string ref, based that the data the input RE-based
template acquired (or that the Munger mangled).  The send operation should use these values to send the converted alert.

== close

Called after the interval loop has been completed.  This should close the connection and run through any cleanup.

This method should double-check all I/O cleanup with the {opened} method to ensure that close doesn't fail.  This is important if the loop
detects that the {opened} method is false, since it will try a {close} before trying to re-open.

= PERSISTENT CONNECTIONS

Persistent connections can be done by defining {close} in such a way that it still keeps the connection online, and making sure {opened} can
handle the state.  Take special care to check that the connection is indeed valid and the module can handle re-opens properly.

=end wikidoc
