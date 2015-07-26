from time import gmtime, strftime
import argparse
import urllib.parse

parser = argparse.ArgumentParser(description='Example python script')
parser.add_argument('-myparam', dest='myparam', type=str, help='Example parameter')

def writeCustomizedMsg(msg):
  timestr = strftime("[%Y-%m-%d %H:%M:%S] ", gmtime())
  print("<customizedOutput>" + timestr + msg + "</customizedOutput>")
  
def writeStdout(msg):
  print("<stdOutput><![CDATA[" + msg + "]]></stdOutput>")

args = parser.parse_args()
myparam = urllib.parse.unquote_plus(args.myparam)

writeCustomizedMsg("Hello webCommander")
writeStdout(myparam)