package Transform::Alert::Output::Syslog;

our $VERSION = '0.90'; # VERSION
# ABSTRACT: Transform alerts to Syslog alerts

use sanity;
use Moo;
use MooX::Types::MooseLike::Base 0.15 qw(Str Int ArrayRef HashRef InstanceOf);

use Net::Syslog;

with 'Transform::Alert::Output';

has _conn => (
   is        => 'rw',
   isa       => InstanceOf['Net::Syslog'],
   predicate => 1,
   clearer   => 1,
);

sub open {
   my $self = shift;
   $self->_conn(
      Net::Syslog->new( %{$self->connopts} )
   );

   return 1;
}

# Net::Syslog::send creates new IO::Sockets each time, so 
# just a simple check here...
sub opened { $_[0]->_has_conn; }

sub send {
   my ($self, $msg) = @_;
   my $syslog = $self->_conn;
   
   unless (eval { $syslog->send($msg) }) {   
      $self->log->error('Error sending Syslog message: '.$@);
      return;
   }
   return 1;
}

sub close { 1; }

42;



=pod

=encoding utf-8

=head1 NAME

Transform::Alert::Output::Syslog - Transform alerts to Syslog alerts

=head1 SYNOPSIS

    # In your configuration
    <Output test>
       Type          Syslog
       TemplateFile  outputs/test.txt
 
       # See Net::Syslog->new
       <ConnOpts>
          Name       TransformAlert
          Facility   local4
          Priority   info
          SyslogHost syslog.foobar.org
          SyslogPort 514  # default
       </ConnOpts>
    </Output>

=head1 DESCRIPTION

This output type will send a syslog alert for each converted input.

See L<Net::Syslog> for a list of the Options section parameters.

=head1 CAVEATS

L<Net::Syslog> has UDP connections hard-coded into its module.  TCP
usage is rare, anyway.

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

