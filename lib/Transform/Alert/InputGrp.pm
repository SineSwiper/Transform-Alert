package Transform::Alert::InputGrp;

# VERSION
# ABSTRACT: Base class for Transform::Alert input groups

use sanity;
use Moo;
use MooX::Types::MooseLike::Base 0.15 qw(Str Int Num ScalarRef ArrayRef InstanceOf ConsumerOf);

use Storable 'dclone';
use Time::HiRes 'time';

has daemon => (
   is       => 'ro',
   isa      => InstanceOf['Transform::Alert'],
   weak_ref => 1,
   handles  => [ 'log' ],
);
has input => (
   is       => 'ro',
   isa      => ConsumerOf['Transform::Alert::Input'],
   required => 1,
);
has templates => (
   is       => 'ro',
   isa      => ArrayRef[InstanceOf['Transform::Alert::TemplateGrp']],
   required => 1,
);

has interval => (
   is       => 'ro',
   isa      => Int,
   default  => sub { 60 },
);
has last_finished => (
   is       => 'rw',
   isa      => Num,
   lazy     => 1,
   default  => sub { time; },
);

around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   # temp hash with output objects
   my $outs = delete $hash->{output_objs};

   # create input first
   my $name = delete $hash->{name};
   my $type = delete $hash->{type} || die "Input '$name' requires a Type!";
   $hash->{input} = "Transform::Alert::Input::$type"->new(
      connopts => delete $hash->{connopts}
   );
   
   # translate templates
   $hash->{template} = [ $hash->{template} ] unless (ref $hash->{template} eq 'ARRAY');
   $hash->{template} = [ map {
      $_->{output_objs} = $outs;
      Transform::Alert::TemplateGrp->new($_);
   } @{ $hash->{template} } ];
   
   $orig->($self, $hash);
};

after BUILD => sub {
   my $self = shift;
   $_->_set_in_group($self) for (@{ $self->templates });
   $self->input->_set_group($self);
};


sub process {
   my $self = shift;
   my ($in, $log) = ($self->input, $self->log);
   $log->debug('Processing input...');
   
   unless ($in->opened) {
      $log->debug('Opening input connection');
      $in->open;
   }
   until ($in->eof) {
      # get a message
      my $msg = $in->get;
      unless (defined $msg) {
         $self->warn('Input error... bailing out of this process cycle!');
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
   my $log  = $self->log;
   $log->debug('Closing all I/O for this group');

   $self->input->close;
   $_->close_all for (@{ $self->templates });
   
   $self->last_finished(time);
   $log->debug('Finish time marker');
   
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
