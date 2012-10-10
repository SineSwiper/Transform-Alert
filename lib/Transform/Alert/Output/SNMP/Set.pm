package Transform::Alert::Output::SNMP::Set;

# VERSION
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

__END__

=begin wikidoc

= SYNOPSIS

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
 
= DESCRIPTION
 
This output type will send a SNMP set request for each converted input.  See [Net::SNMP] for a list of the ConnOpts section parameters.

= OUTPUT FORMAT

Output templates should use the following format:

   1.3.6.1.2.#.#.#.#  #  Value, blah blah blah...
   1.3.6.1.2.#.#.#.#  #  Value, blah blah blah...

In other words, each line is a set of varbinds.  Within each line is a set of 3 values, separated by whitespace:

* OID
* Object Type (numeric form)
* Value

A list of object types can be found [here|https://metacpan.org/source/Net::SNMP::Message#L75].
   
= TODO

Use [Net::SNMPu], when that gets released...

=end wikidoc
