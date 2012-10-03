package Transform::Alert::TemplateGrp;

# VERSION
# ABSTRACT: Base class for Transform::Alert template groups

use sanity;
use Moo;
use MooX::Types::MooseLike::Base 0.15 qw(Str ScalarRef ArrayRef InstanceOf ConsumerOf);

has in_group => (
   is       => 'ro',
   isa      => InstanceOf['Transform::Alert::InputGrp'],
   required => 1,
   weak_ref => 1,
   handles  => [qw( log daemon )],
);
has text => (
   is       => 'ro',
   isa      => ScalarRef[Str],
   required => 1,
);
has outputs => (
   is       => 'ro',
   isa      => ArrayRef[ConsumerOf['Transform::Alert::IO']],
   required => 1,
);

sub send_all {
   my ($self, $vars) = @_;
   
   foreach my $out (@{ $self->outputs }) {
      my $out_tmpl = ${ $out->template };  # need to modify the string, hence non-ref
      
      foreach my $v (keys %$vars) {
         my ($s, $d) = (quotemeta('{{{'.$v.'}}}'), $vars->{$v});
         $out_tmpl =~ s/$s/$d/g;
      }
      
      # send alert
      $out->open unless $out->opened;
      unless ($out->send($out_tmpl)) {
         $self->log('Output error... bailing out of this process cycle!');
         $self->close_all;
         return;
      }
   }
   
   return 1;
}

sub close_all {
   my $self = shift;
   $_->close for (@{ $self->outputs });
   return 1;
}

42;

__END__

=begin wikidoc

= SYNOPSIS
 
   # code
 
= DESCRIPTION
 
Insert description here...

= CAVEATS

Bad stuff...

= SEE ALSO

Other modules...

= ACKNOWLEDGEMENTS

Thanks and stuff...

=end wikidoc
