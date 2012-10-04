package Transform::Alert::InputGrp;

our $VERSION = '0.90'; # VERSION
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



=pod

=encoding utf-8

=head1 NAME

Transform::Alert::InputGrp - Base class for Transform::Alert input groups

=head1 SYNOPSIS

    # code

=head1 DESCRIPTION

Insert description here...

=head1 CAVEATS

Bad stuff...

=head1 SEE ALSO

Other modules...

=head1 ACKNOWLEDGEMENTS

Thanks and stuff...

=head1 AVAILABILITY

The project homepage is L<https://github.com/SineSwiper/Transform-Alert/wiki>.

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<https://metacpan.org/module/Transform::Alert/>.

=head1 AUTHOR

Brendan Byrd <BBYRD@CPAN.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Brendan Byrd.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut


__END__

