package Transform::Alert::TemplateGrp;

our $VERSION = '0.90'; # VERSION
# ABSTRACT: Base class for Transform::Alert template groups

use sanity;
use Moo;
use MooX::Types::MooseLike::Base 0.15 qw(Str ScalarRef HashRef InstanceOf ConsumerOf);

use Data::Dump 'pp';

has in_group => (
   is       => 'rwp',
   isa      => InstanceOf['Transform::Alert::InputGrp'],
   weak_ref => 1,
   handles  => [ 'log' ],
);
has text => (
   is       => 'ro',
   isa      => ScalarRef[Str],
   required => 1,
);
has outputs => (
   is       => 'ro',
   isa      => HashRef[ConsumerOf['Transform::Alert::Output']],
   required => 1,
);

around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   # temp hash with output objects
   my $outs = delete $hash->{output_objs};
   
   # replace OutputNames with Outputs
   my $outputs = delete $hash->{outputname};
   $outputs = [ $outputs ] unless (ref $outputs eq 'ARRAY');
   $hash->{outputs} = [ map {
      $_ = $outs->{$_} || die "OutputName '$_' doesn't have a matching Output block!";
   } @$outputs ];
   
   # replace TemplateFile with template
   if (my $tmpl_file = delete $hash->{templatefile}) {
      my $tmpl_text = read_file($tmpl_file);
      $hash->{text} = \$tmpl_text;
   }
   
   $orig->($self, $hash);
};

sub send_all {
   my ($self, $vars) = @_;
   my $log = $self->log;
   $log->debug('Processing outputs...');
   $log->debug(pp $vars);
   
   foreach my $out_key (keys %{ $self->outputs }) {
      $log->debug('Looking at Output "'.$out_key.'"...');
      my $out = $self->outputs->{$out_key};
      my $out_tmpl = ${ $out->template };  # need to modify the string, hence non-ref
      
      foreach my $v (keys %$vars) {
         my ($s, $d) = ('\[\%\s+'.quotemeta($v).'\s+\%\]', $vars->{$v});
         $out_tmpl =~ s/$s/$d/g;
      }
      
      # send alert
      unless ($out->opened) {
         $log->debug('Opening output connection');
         $out->open;
      }
      $log->info('Sending alert for "'.$out_key.'"');
      ### TODO: Add message text ###
      unless ($out->send($out_tmpl)) {
         $self->warn('Output error... bailing out of this process cycle!');
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



=pod

=encoding utf-8

=head1 NAME

Transform::Alert::TemplateGrp - Base class for Transform::Alert template groups

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

