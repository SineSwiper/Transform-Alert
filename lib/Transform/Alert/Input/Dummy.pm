package Transform::Alert::Input::Dummy;

our $VERSION = '0.96'; # VERSION
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

=pod

=encoding utf-8

=head1 NAME

Transform::Alert::Input::Dummy - Transform alerts from random messages

=head1 SYNOPSIS

    # In your configuration
    <Input test>
       Type      Dummy
       Interval  60  # seconds (default)
 
       <ConnOpts/>
       <Template>
          TemplateFile  dummy.re
          OutputName    null
       </Template>
    </Input>

=head1 DESCRIPTION

This input type is used for testing.

=head1 OUTPUTS

=head2 Text

A dummy string

=head2 Preparsed Hash

    {
       item => $str
    }

=cut
