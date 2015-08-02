Video Tutorials
===============

1. How to execute an individual command http://youtu.be/CREkoloCOmk
2. Workflow basics http://youtu.be/ZJtU36kM2YY
3. Workflow variable http://youtu.be/i6z_HKgeiqY
4. Workflow template http://youtu.be/adXa6AHJaB8
5. Run workflow as command https://youtu.be/DAm70VO62VY

webcommander
============

!!! PLEASE NOTE THAT ADVANCED INFORMATIONS ARE PROVIDED IN WIKI !!!
https://github.com/vmware/webcommander/wiki

WebCommander wraps scripts into web services so that those scripts could be easily consumed by remote users or other programs. Each script becomes a command that could be triggered by HTTP request. The command output is XML with browser side transforming (XSLT) which is friendly to both programs and human users at the same time. 

WebCommander also provides 2 methods (workflow and poker) to run multiple commands together to fulfill more complex automation tasks.

WebCommander currently supports Powershell, Perl, Python and Ruby scripts. The built-in Powershell scripts are mainly for automating VMware vSphere and Horizon View. As for Perl, Python and Ruby, only 1 example script is provided respectively to illustrate how to add uses' own scripts into WebCommander. 

If you want to contribute code or get any idea to improve WebCommander,
Please contact Jerry Liu (liuj@vmware.com, Skype: whirls9@hotmail.com).  

To install and config WebCommander, simply download the Powershell script below.
https://github.com/vmware/webcommander/blob/master/powershell/Install/setup.ps1
Then run it on a Windows 2012 or 2008 server where Powershell 4.0 has already been installed.
Please note that this script also supports upgrading WebCommander with new source codes.
A more detailed guide for manual install and configuration is provided in wiki https://github.com/vmware/webcommander/wiki/Installation-and-configuration-guide
