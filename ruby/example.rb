require 'optparse'
require 'cgi'

options = {}
OptionParser.new do |opts|
  opts.on('--myparam myparam', 'Example parameter') { |v| options[:myparam] = v }
end.parse!

def writeCustomizedMsg(msg)
  timestr = Time.new.strftime("[%F %T] ")
  puts("<customizedOutput>" + timestr + msg + "</customizedOutput>")
end
  
def writeStdout(msg)
  puts("<stdOutput><![CDATA[" + msg + "]]></stdOutput>")
end

myparam = CGI.unescape(options[:myparam])

writeCustomizedMsg("Hello webCommander")
writeStdout(myparam)