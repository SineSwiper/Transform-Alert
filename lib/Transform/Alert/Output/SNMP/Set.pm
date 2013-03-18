package Transform::Alert::Output::SNMP::Set;

our $VERSION = '0.96'; # VERSION
# ABSTRACT: Transform alerts to SNMP set requests

use sanity;
use Moo;

extends 'Transform::Alert::Output::SNMP';

sub send {
   my ($self, $msg) = @_;
   my $snmp = $self->_session || return;
   
   $snmp->set_request(
      -varbindlist => $self->_translate_msg($msg),
   ) || do {
      $self->log->error('Error sending SNMP set request: '.$snmp->error);
      return;
   };
   
   return 1;
}

42;



=pod

=encoding utf-8

=head1 NAME

Transform::Alert::Output::SNMP::Set - Transform alerts to SNMP set requests

=head1 SYNOPSIS

    # In your configuration
    <Output test>
       Type          SNMP::Set
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

This output type will send a SNMP set request for each converted input.  See L<Net::SNMP> for a list of the ConnOpts section parameters.

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

=head1 TODO

Use L<Net::SNMPu>, when that gets released...

=cut


__END__

