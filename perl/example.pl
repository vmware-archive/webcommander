use Getopt::Long;
use POSIX qw(strftime);

sub writeCustomizedMsg {
  my ($msg) = @_;
  my $timestr = strftime "[%Y-%m-%d %H:%M:%S] ", localtime;
  print "<customizedOutput>$timestr$msg</customizedOutput>";
}

sub writeStdout {
  my ($msg) = @_;
  print "<stdOutput><![CDATA[$msg]]></stdOutput>"
}

sub urldecode {
  my ($s) = @_;
  $s =~ tr/\+/ /;
  $s =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/eg;
  return $s;
}

GetOptions ("myparam=s" => \$myparam);
$myparam = urldecode($myparam) ;

writeCustomizedMsg("Hello webCommander");
writeStdout($myparam);