package Transform::Alert::Input::SNMPTrapd;

# VERSION
# ABSTRACT: Transform alerts from an internal SNMP Trap daemon

use sanity;
use Moo;
use MooX::Types::MooseLike::Base qw(InstanceOf);

use Net::SNMPTrapd;

with 'Transform::Alert::Input';

has _conn => (
   is        => 'rw',
   isa       => InstanceOf['Net::SNMPTrapd'],
   lazy      => 1,
   default   => sub {
      Net::SNMPTrapd->new( %{shift->connopts} ) || die "SNMPTrapd New failed: ".Net::SNMPTrapd->error;
   },
   predicate => 1,
);

sub open   { shift->_conn     }
sub opened { shift->_has_conn }

sub get {
   my $self    = shift;
   my $trapd = $self->_conn;
   
   my $trap = $trapd->get_trap(Timeout => 0);
   
   unless (defined $trap) {
      $self->log->error('Error grabbing SNMP trap: '.$trapd->error);
      return;
   }
   if ($trap eq '0') {
      $self->log->warn('No SNMP trap in queue during get()');
      return \(''), {};
   }
   
   # rejoin message parts
   my $txt = $trap->remoteaddr.':'.$trap->remoteport.' - '.$trap->datagram;
   $trap->process_trap;
   return (\$txt, {
      remoteaddr => $trap->remoteaddr,
      remoteport => $trap->remoteport,
      
      version   => $trap->version,
      community => $trap->community,
      pdu_type  => $trap->pdu_type,
      varbinds  => $trap->varbinds,
      
      ($trap->version == 1 ? (
         ent_OID       => $trap->ent_OID,
         agentaddr     => $trap->agentaddr,
         generic_trap  => $trap->generic_trap,
         specific_trap => $trap->specific_trap,
         timeticks     => $trap->timeticks,
      ) : (
         request_ID    => $trap->request_ID,
         error_status  => $trap->error_status,
         error_index   => $trap->error_index,
      )),
   });
}

sub eof {
   my $self = shift;
   my $port = $self->_conn->server;

   # check if a message is waiting
   my $rin = '';
   vec($rin, fileno($port), 1) = 1; 
   return not select($rin, undef, undef, 0);
}

sub close { 1 }

42;

__END__

=begin wikidoc

= SYNOPSIS

   # In your configuration
   <Input test>
      Type      SNMPTrapd
      Interval  5  # you should set this to be very short
      
      # See Net::SNMPTrapd->new
      <ConnOpts>
         LocalAddr  192.168.1.1
         LocalPort  514  # default
         # Timeout - don't bother
      </ConnOpts>
      # <Template> tags...
   </Input>
 
= DESCRIPTION
 
This input type will spawn a SNMP trap listener and process each trap through the input template engine.  If it finds a match, the results of
the match are sent to one or more outputs, depending on the group configuration.

See [Net::SNMPTrapd] for a list of the ConnOpts section parameters.  The {Timeout} parameter is basically ignored, since {get_trap} calls will
use a timeout of 0 (ie: instant).  This is so that the main daemon doesn't bother waiting for messages during each heartbeat.  As such, the
{Interval} setting should be set very low.  (But, not zero; that would be unwise...)

= OUTPUTS

== Text

   $addr:$port - $datagram

== Preparsed Hash

   {
      remoteaddr => $str,
      remoteport => $int,
      
      version   => $int,  # 1 = SNMPv1, 2 = SNMPv2c
      community => $str,
      pdu_type  => $str,  # text version
      varbinds  => [
         [{ $OID => $value }],
         [{ $OID => $value }],
         # ...
      ],

      # SNMPv1 only
      ent_OID       => $str,
      agentaddr     => $str,
      generic_trap  => $str,  # text version
      specific_trap => $str,
      timeticks     => $int,

      # SNMPv2 only
      request_ID    => $str,
      error_status  => $str,
      error_index   => $int,
   }

= CAVAETS

Admittedly, the datagram of a SNMP trap isn't all that useful, so the text version is somewhat useless...
   
=end wikidoc
