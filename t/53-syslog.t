use sanity;
use Test::Most tests => 9;
use Test::LeakTrace;

use Path::Class;
use lib dir(qw{ t lib })->stringify;
use TestDaemon;

my ($ta, $log_file) = TestDaemon->new(qw{ syslog syslog });

# let's start the loop with a message
use Net::Syslog 0.04;  # 0.04 has rfc3164 flag

$ta->heartbeat;  # starts the daemon for the first time
my $syslog = Net::Syslog->new(
   Name       => 'TransformAlert',
   Facility   => 'local3',
   Priority   => 'info',
   SyslogHost => '127.0.0.244',
   SyslogPort => 51437,
   rfc3164    => 1,
);
$syslog->send('Two-three-oh-five-eight-four-three-oh-oh-nine-two-one-three-six-nine-three-nine-five-one');

lives_ok { $ta->heartbeat } 'heartbeat';

# check the log for the right phrases
my $log = $log_file->slurp;

foreach my $str (
   'severity   => "Informational",',
   'remoteaddr => "127.0.0.244",',
   'priority   => 158,',
   'message    => "Two-three-oh-five-eight-four-three-oh-oh-nine-two-one-three-six-nine-three-nine-five-one",',
   'facility   => "local3",',
   'Sending alert for "syslog"',
   'Munger cancelled output',
) {
   like($log, qr/\Q$str\E/, "Found - $str");
}

no_leaks_ok {
   $syslog->send('Oh-dot-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-oh-four-three-three-six-eight-oh-eight-oh-six-eight-nine-nine-four-two');
   $ta->heartbeat;
} 'no memory leaks';