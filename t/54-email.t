use sanity;
use Test::Most (
   $ENV{TATEST_POP3_JSONY} && $ENV{TATEST_SMTP_JSONY} && $ENV{TATEST_EMAIL_ADDY} ?
      tests => 9 :
      skip_all => 'Set $ENV{TATEST_POP3_JSONY}, _SMTP_JSONY, and _EMAIL_ADDY to run this test.'
);
use Test::LeakTrace;

use JSONY;
use Path::Class;
use lib dir(qw{ t lib })->stringify;
use TestDaemon;

# JSONY parse
my $pop3_conf = decode_jsony $ENV{TATEST_POP3_JSONY};
my $smtp_conf = decode_jsony $ENV{TATEST_SMTP_JSONY};

$pop3_conf = { @$pop3_conf } if (ref $pop3_conf eq 'ARRAY');
$smtp_conf = { @$smtp_conf } if (ref $smtp_conf eq 'ARRAY');

# extra defaults
$pop3_conf->{timeout} //= 20;
$smtp_conf->{timeout} //= 20;

my ($ta, $log_file) = TestDaemon->new(qw{ syslog syslog }, {
   '{input}{pop3}{connopts}'   => $pop3_conf,
   '{output}{email}{connopts}' => $smtp_conf,
});

# let's start the loop with a message

# (use TA's own output object to compose the email)
my $out = $ta->outputs->{email};
my $tt = Template->new();
my $out_str = '';
my $vars = {
   subject => 'Test Problem 0',
   name    => 'dogbert'.rand(44444).'q',
   problem => 'It broke!',
   ticket  => 'TT0000000000',
};

$tt->process($out->template, $vars, \$out_str);

ok($out->open, 'open output');
ok($out->send(\$out_str), 'send output');

lives_ok { $ta->heartbeat } 'heartbeat 1';
lives_ok { $ta->heartbeat } 'heartbeat 2';

# check the log for the right phrases
my $log = $log_file->slurp;

foreach my $str (
   'severity   => "Informational",',
   'remoteaddr => ',  # some OSs might force the address back to 127.0.0.1 or say "localhost"
   'priority   => 158,',
   'message    => "'.$msg.'",',
   'facility   => "local3",',
   'Sending alert for "syslog"',
   'Munger cancelled output',
) {
   #ok($log =~ qr/\Q$str\E/, "Found - $str");
}

no_leaks_ok {
   $ta->heartbeat;
} 'no memory leaks';

$log_file->remove;
