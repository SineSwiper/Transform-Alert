package Transform::Alert::InputGrp;

# VERSION
# ABSTRACT: Base class for Transform::Alert input groups

use sanity;
use Moo;
use MooX::Types::MooseLike::Base qw(Str Int Num ScalarRef ArrayRef InstanceOf ConsumerOf);

use Transform::Alert::TemplateGrp;

use Time::HiRes 'time';
use Class::Load 'load_class';
use String::Escape qw(elide printable);

use namespace::clean;

has daemon => (
   is       => 'rwp',
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
   default  => sub { 0 },
);
sub time_left {
   my $self = shift;
   time - $self->last_finished + $self->interval;
}

around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   # temp hash with output objects
   my $outs = delete $hash->{output_objs};

   # create input first
   my $name = delete $hash->{name};
   my $type = delete $hash->{type} || die "Input '$name' requires a Type!";
   my $class = "Transform::Alert::Input::$type";
   load_class $class;
   $hash->{input} = $class->new(
      connopts => delete $hash->{connopts}
   );
   
   # translate templates
   $hash->{template}  = [ $hash->{template} ] unless (ref $hash->{template} eq 'ARRAY');
   $hash->{templates} = [ map {
      $_->{output_objs} = $outs;
      Transform::Alert::TemplateGrp->new($_);
   } @{ delete $hash->{template} } ];
   
   $orig->($self, $hash);
};

sub BUILD {
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
      my ($msg, $hash) = $in->get;
      unless (defined $msg) {
         $self->warn('Input error... bailing out of this process cycle!');
         $self->close_all;
         return;
      }
      $log->info('   Found message: '.printable(elide($$msg, 200)) );
      
      # start the matching process
      foreach my $tmpl (@{ $self->templates }) {
         # input RE templates
         my $vars = {};
         if ($tmpl->regexp) {
            next unless ($$msg =~ $tmpl->regexp);  # found one
            $vars = { %+ };  # untie
         }
         $tmpl->send_all({
            t => $vars,
            p => $hash,
         });
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
 
   # In your configuration
   <Input [name]>
      Type      [type]
      Interval  60  # seconds (default)
      
      # <ConnOpts> section; module-specific
      # <Template> sections
   </Input>
 
= DESCRIPTION

This is essentially a class used for handling {Input} sections.  In the grand scheme of things, the classes follow this hierarchy:

   transalert_ctl
      Transform::Alert
         TA::InputGrp
            TA::Input::*
            TA::TemplateGrp
               TA::Output::* (referenced from the main TA object)
         TA::Output::* (stored list only)

In fact, the configuration file is parsed recursively in this fashion.

However, this isn't really a user-friendly interface.  So, shoo!

= SEE ALSO

[Transform::Alert], which is what you should really be reading...

=end wikidoc
