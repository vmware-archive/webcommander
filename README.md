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

There are many Powershell and PowerCLI Users ranging from vSphere Administrators to developers, 
all of these are creating scripts to aid with common automation tasks and integration. Their 
scripts are highly valuable resources that should be reused and shared.

However, it may not be convenient enough for people to use Powershell scripts directly from their
own machine, environment or framework. For instance, the QE team of View Android Client writes 
test cases in JAVA running on the mobile devices. How could they make use of the Powershell scripts?
A common customer example is where vSphere Admins need to hand off tasks or common reporting 
information to other areas of the business or to the help desk, to do this every person currently
needs .Net/PowerShell and PowerCLI installed on their machine and the knowledge to run or even write 
the code, even then they will still get a textual interface to what should be an easy to hand off 
automation task. 

Moreover, it’s necessary to establish a centralized way to control these scripts. It is often 
troublesome to distribute and update them especially for external users.

To solve these problems, we developed WebCommander which wraps Powershell scripts into web services
and presents them as a simple one-click automation solution. This can be likened to an "App Store"
for PowerShell/PowerCLI !

Wrapping a program as a web service means using a web portal to gather parameters and then passing 
them to the wrapped program. By doing so, details on how the program is developed and what
underlying system it depends on become transparent to others. People could make easy use of the 
program via browser manually or through any programming language that supports calling web services.

End users usually run many repeatable routines which could be automated by PowerCLI. WebCommander 
makes it even easier by providing a more user friendly UI and result report. Users have no need to 
setup their own environment to use PowerCLI, keep upgrading it, download and learn scripts written 
by others.

There are many tools to automate VMware products, such as esxcli, java-sdk, perl-sdk. Although none 
of these are as simple to use or powerful than PowerCLI (in our opinion), they are still required by 
both internal and external customers. Why so? Because their existing automation frameworks make them
use these. For instance, View Linux client QE team uses Jython to develop test scripts running on 
Linux. Considering PowerCLI only runs on Windows, java-api is more preferable to them obviously. By 
wrapping PowerCLI scripts into web services, this problem is solved. Each WebCommander service could 
be triggered with an URL which is supported by almost all other languages. And the returned result, 
although looks pretty in browser, is pure XML which is usable as a data entry point to other 
languages.

By providing centralized web services instead of distributed scripts, we just need to setup and 
maintain a single server without worrying about issues caused by different environments. We can 
update the application whenever we want without worrying if end users code is not synchronized. 

WebCommander can also be used to easily create the entire environment via scripts and an exported 
JSON file which can be shared with others, we could potentially define the complete SDDC in code!

In October 2013, WebCommander was published as a Fling. We received a lot of encouraging feedback 
and feature requests from external users. Many users already started to add their own scripts and
enhancements into their environments. Considering their contributions could be beneficial to all
WebCommander users, we decide to create this open source project on Github. Everybody is welcome
to clone or contribute to this project.

If you want to check in your code to the master repository or get any idea to improve WebCommander,
Please contact Jerry Liu (liuj@vmware.com, Skype: whirls9@hotmail.com).  

To install and config WebCommander, simply download the Powershell script below.
https://github.com/vmware/webcommander/blob/master/powershell/Install/setup.ps1
Then run it on a Windows 2012 or 2008 server where Powershell 4.0 has already been installed.
Please note that this script also supports upgrading WebCommander with new source codes.
