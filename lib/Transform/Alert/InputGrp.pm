package Transform::Alert::InputGrp;

# VERSION
# ABSTRACT: Base class for Transform::Alert input groups

use sanity;
use Moo;
use MooX::Types::MooseLike::Base 0.15 qw(Str ScalarRef ArrayRef InstanceOf ConsumerOf);

use Storable 'dclone';

has daemon => (
   is       => 'ro',
   isa      => InstanceOf['Transform::Alert'],
   required => 1,
   weak_ref => 1,
   handles  => [ 'log' ],
);
has input => (
   is       => 'ro',
   isa      => ConsumerOf['Transform::Alert::IO'],
   required => 1,
);
has templates => (
   is       => 'ro',
   isa      => ArrayRef[InstanceOf['Transform::Alert::TemplateGrp']],
   required => 1,
);

sub process {
   my $self = shift;
   my $in   = $self->input;
   
   $in->open unless $in->opened;
   until ($in->eof) {
      # get a message
      my $msg = $in->get;
      unless (defined $msg) {
         $self->log('Input error... bailing out of this process cycle!');
         $self->close_all;
         return;
      }
      
      # start the matching process
      foreach my $tmpl (@{ $self->templates }) {
         my $in_tmpl = '^'.$tmpl->text.'$';
         $tmpl->send_all(dclone \%+) if ($$msg =~ $$in_tmpl);  # found one
      }
   }
   $self->close_all;
   
   return 1;
}

sub close_all {
   my $self = shift;

   $self->input->close;
   $_->close_all for (@{ $self->templates });
   
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
