package Transform::Alert::Output::Syslog;

our $VERSION = '0.95_002'; # VERSION
# ABSTRACT: Transform alerts to Syslog alerts

use sanity;
use Moo;
use MooX::Types::MooseLike::Base qw(InstanceOf);

use Net::Syslog;

with 'Transform::Alert::Output';

has _conn => (
   is        => 'rw',
   isa       => InstanceOf['Net::Syslog'],
   lazy      => 1,
   default   => sub { Net::Syslog->new( %{shift->connopts} ) },
   predicate => 1,
);

# Net::Syslog is a bit picky about its case-sensitivity
around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   foreach my $keyword (qw{ Name Facility Priority Pid SyslogPort SyslogHost }) {
      $hash->{connopts}{$keyword} = delete $hash->{connopts}{lc $keyword} if (exists $hash->{connopts}{lc $keyword});
   }
   
   $orig->($self, $hash);
};

sub open   { shift->_conn; }
sub opened { shift->_has_conn; }

sub send {
   my ($self, $msg) = @_;
   my $syslog = $self->_conn;
   
   unless (eval { $syslog->send($$msg) }) {   
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
       TemplateFile  outputs/test.tt
 
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

See L<Net::Syslog> for a list of the ConnOpts section parameters.

=head1 CAVEATS

L<Net::Syslog> has UDP connections hard-coded into its module.  TCP
usage is rare, anyway.

=cut


__END__

