package Transform::Alert::Output::Print;

# VERSION
# ABSTRACT: Transform alerts to plain text STDOUT messages

use sanity;
use Moo;
use MooX::Types::MooseLike::Base qw(InstanceOf);

with 'Transform::Alert::Output';

sub open   { 1 }
sub opened { 1 }
sub send   { print $_[1]; 1; }
sub close  { 1 }

42;

__END__

=begin wikidoc

= SYNOPSIS

   # In your configuration
   <Output print>
      Type          Print
      TemplateFile  outputs/test.tt
      <ConnOpts/>
   </Output>

= DESCRIPTION

This output type is mainly used for testing.

=end wikidoc
