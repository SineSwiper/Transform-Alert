use Data::Dump;
use Config::General;

$conf = Config::General->new(
   -String => '
   BaseDir /opt/trans_alert
   
   <Input test_in>
      Type      POP3
      Interval  60  # seconds (default)
      
      <ConnOpts>
         Username  bob
         Password  mail4fun
         
         # See Net::POP3->new
         Host     mail.foobar.org
         Port     110  # default
         Timeout  120  # default
      </ConnOpts>

      <Template>
         TemplateFile  test_in/foo_sys_email.txt
         OutputName    test_out
      </Template>
      <Template>
         TemplateFile  test_in/server01_email.txt
         OutputName    test_out
      </Template>         
   </Input>
   <Input test_a>
      Type      POP3
      Interval  60  # seconds (default)
      
      <ConnOpts/>

      <Template>
         TemplateFile  test_in/foo_sys_email.txt
         OutputName    test_out
      </Template>
      <Template>
         TemplateFile  test_in/server01_email.txt
         OutputName    test_out
      </Template>         
   </Input>
   <Output test_out>
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
   </Output>',
   -LowerCaseNames => 1,
);

dd { $conf->getall };