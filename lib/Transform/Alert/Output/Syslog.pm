package Transform::Alert::Output::Syslog;

# VERSION
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

__END__

=begin wikidoc

= SYNOPSIS

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
 
= DESCRIPTION
 
This output type will send a syslog alert for each converted input.

See [Net::Syslog] for a list of the Options section parameters.

= CAVEATS

[Net::Syslog] has UDP connections hard-coded into its module.  TCP
usage is rare, anyway.

=end wikidoc
