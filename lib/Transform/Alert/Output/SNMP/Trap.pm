package Transform::Alert::Output::SNMP::Trap;

our $VERSION = '1.00'; # VERSION
# ABSTRACT: Transform alerts to SNMP traps

use sanity;
use Moo;

extends 'Transform::Alert::Output::SNMP';

sub send {
   my ($self, $msg) = @_;
   my $snmp = $self->_session || return;
   
   # We're just going to assume that the version requirements are already met
   $snmp->snmpv2_trap(
      -varbindlist => $self->_translate_msg($msg),
   ) || do {
      $self->log->error('Error sending SNMPv2 trap: '.$snmp->error);
      return;
   };
   
   return 1;
}

42;

__END__

=pod

=encoding utf-8

=head1 NAME

Transform::Alert::Output::SNMP::Trap - Transform alerts to SNMP traps

=head1 SYNOPSIS

    # In your configuration
    <Output test>
       Type          SNMP::Trap
       TemplateFile  outputs/test.tt
 
       # See Net::SNMP->new
       <ConnOpts>
          Hostname      snmp.foobar.org
          Port          161  # default
          Version       1    # default
          Community     public  # default
          # ...etc., etc., etc...
 
          # NonBlocking - DO NOT USE!
       </ConnOpts>
    </Output>

=head1 DESCRIPTION

This output type will send a SNMP trap for each converted input.  See L<Net::SNMP> for a list of the ConnOpts section parameters.

=head1 OUTPUT FORMAT

Output templates should use the following format:

    1.3.6.1.2.#.#.#.#  #  Value, blah blah blah...
    1.3.6.1.2.#.#.#.#  #  Value, blah blah blah...

In other words, each line is a set of varbinds.  Within each line is a set of 3 values, separated by whitespace:

=over

=item *

OID

=item *

Object Type (numeric form)

=item *

Value

=back

A list of object types can be found L<here|https://metacpan.org/source/Net::SNMP::Message#L75>.

Please note that SNMPv2 defines the first two variables bindings as such:

     # sysUpTime.0   TIMETICKS          $timeticks
     # snmpTrapOID.0 OBJECT_IDENTIFIER  $oid
     1.3.6.1.2.1.1.3.0       43  ....
     1.3.6.1.6.3.1.1.4.1.0    6  ....

Make sure these are included in your template.

=head1 CAVEATS

No support for SNMPv1 traps yet, as the sending format is very different.  Patches welcome!

=head1 TODO

Use L<Net::SNMPu>, when that gets released...

=cut
