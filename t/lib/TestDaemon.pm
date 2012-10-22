package TestDaemon;

use sanity;
use Devel::SimpleTrace;

use Transform::Alert;

use Log::Log4perl;
use Config::General;
use Path::Class;
use File::Slurp 'read_file';

use lib dir('lib')->absolute->stringify;  # paths keep changing...

sub new {
   my ($class, $dir, $name, $conf_insert) = @_;

   my $conf_file = dir()->file('corpus', $dir, "$name.conf")->resolve->absolute;
   my $log_file  = $conf_file->dir->file("$name.log");

   # init the logger...
   $log_file->remove;
   Log::Log4perl->init(\ qq{
      log4perl.logger = DEBUG, FileApp
      log4perl.appender.FileApp = Log::Log4perl::Appender::File
      log4perl.appender.FileApp.filename = $log_file
      log4perl.appender.FileApp.layout   = PatternLayout::Multiline
      log4perl.appender.FileApp.layout.ConversionPattern = [%d{ISO8601}] [%-5p] {%-25M{2}} %m%n
   });
   my $log = Log::Log4perl->get_logger();

   # ...and start using it immediately
   $SIG{__DIE__} = sub {
      # We're in an eval {} and don't want log
      # this message but catch it later
      return if ($^S);

      local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
      $log->logdie(@_);
   };

   # config file loading
   my $conf = {
      Config::General->new(
         -ConfigFile     => $conf_file->stringify,
         -LowerCaseNames => 1,
      )->getall
   };

   # configuration inserts, if any
   if ($conf_insert) {
      foreach my $path (keys %$conf_insert) {
         my $val = $conf_insert->{$path};
         eval "\$conf->$path = \$val;";
      }
   }

   # change the working directory to the configuration file,
   # so that BaseDir can use relative paths
   chdir $conf_file->dir->stringify;

   my $ta = Transform::Alert->new(
      config => $conf,
      log    => $log,
   );
   
   return ($ta, $log_file);
}

42;
