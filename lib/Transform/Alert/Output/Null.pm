package Transform::Alert::Output::Null;

# VERSION
# ABSTRACT: Transform alerts to NULL space

use sanity;
use Moo;

with 'Transform::Alert::Output';

sub open   { 1 }
sub opened { 1 }
sub send   { 1 }
sub close  { 1 }

42;

__END__

=begin wikidoc

= SYNOPSIS
 
   # In your configuration
   <Output null>
      Type     Null
      Template ""
      <ConnOpts/>
   </Output>
 
= DESCRIPTION
 
This output type is mainly used for testing.  It can have its
uses to send messages to the bitbucket, though.

=end wikidoc
