package Transform::Alert::Input::Dummy;

# VERSION
# ABSTRACT: Transform alerts from random messages

use sanity;
use Moo;

with 'Transform::Alert::Input';

my @random_nonsense = (
   'I am a meat popsicle.',
   'I am a cheese sandwich.',
   'I am an atomic playboy.',
   'Ich bin ein Berliner!',
);

sub open   { 1 }
sub opened { 1 }
sub get    {
   my $msg = $random_nonsense[int rand(@random_nonsense)];
   return (\$msg, { item => $msg });
}
sub eof    { not int rand(5) }
sub close  { 1 }

42;

__END__

=begin wikidoc

= SYNOPSIS
 
   # In your configuration
   <Input test>
      Type      Dummy
      Interval  60  # seconds (default)
      
      <ConnOpts/>
      <Template>
         TemplateFile  dummy.txt
         OutputName    null
      </Template>
   </Input>
 
= DESCRIPTION
 
This input type is used for testing.

= OUTPUTS

== Text

A dummy string

== Preparsed Hash

   {
      item => $str
   }

=end wikidoc
