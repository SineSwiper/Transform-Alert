use sanity;
use Test::Most tests => 27;
use Test::LeakTrace;

use Path::Class;
use lib dir(qw{ t lib })->stringify;
use TestDaemon;

my ($ta, $log_file) = TestDaemon->new(qw{ nulltest nulltest-multi });

lives_ok { $ta->heartbeat for (1 .. 10) } '10 heartbeats';

# check the log for the right phrases
my $log = $log_file->slurp;

foreach my $str (
   'Looking at Output "null2"...',
   'Looking at Output "null1"...',
   'Looking at Input "test2"...',
   'Looking at Input "test1"...',
   'Found message: Ich bin ein Berliner!',
   'Found message: I am an atomic playboy.',
   'Found message: I am a meat popsicle.',
   'Found message: I am a cheese sandwich.',
   '{ item => "meat popsicle" }',
   '{ item => "cheese sandwich" }',
   '{ item => "atomic playboy" }',
   '{ item => "Ich bin ein Berliner!" }',
   '{ item => "I am an atomic playboy." }',
   '{ item => "I am a meat popsicle." }',
   '{ item => "I am a cheese sandwich." }',
   'Munger cancelled output',
   '{ thingy => "meat popsicle" }',
   '{ thingy => "cheese sandwich" }',
   '{ thingy => "atomic playboy" }',
   '{ thingy => "Ich bin ein Berliner!" }',
   '{ thingy => "I am an atomic playboy." }',
   '{ thingy => "I am a meat popsicle." }',
   '{ thingy => "I am a cheese sandwich." }',
   'Sending alert for "null2"',
   'Sending alert for "null1"',
) {
   like($log, qr/\Q$str\E/, "Found - $str");
}

no_leaks_ok {
   $ta->heartbeat for (1 .. 10);
} 'no memory leaks';

$log_file->remove;
