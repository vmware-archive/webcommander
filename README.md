Video Tutorials
===============

1. How to execute an individual command http://youtu.be/CREkoloCOmk
2. Workflow basics http://youtu.be/ZJtU36kM2YY
3. Workflow variable http://youtu.be/i6z_HKgeiqY
4. Workflow template http://youtu.be/adXa6AHJaB8
5. Run workflow as command http://youtu.be/DAm70VO62VY
6. Save workflow on server http://youtu.be/_aEZhzk_Q2Y

Introduction
============

WebCommander wraps scripts into web services so that those scripts could be easily consumed by remote users or other programs. 
Each script becomes a command that could be triggered by HTTP request. 

There are two parallel branches of this project, master and walnut. Compared to master, walnut has the following advantages:
1. Command definition and output are JSON instead of XML
2. Commands, sharing most parameters in common, are turned into methods of a single command. This removes duplicated parameter definitions, and organizes commands in an object oriented way. 
3. Unified GUI of individual command and workflow
4. Changes (add,delete,update) to commands are effective during workflow execution    
5. Users could save workflow on server
6. Could execute commands located on cloud without storing them locally on webcommander server
7. Execution history are stored in MongoDB

Installation
============

To deploy webcommander on Windows 2008 or 2012, please follow the instructions at wiki https://github.com/vmware/webcommander/wiki/Installation-and-configuration-guide
For non server Windows (vista and newer), checkout source code from walnut branch and open www folder from WebMatrix (https://www.microsoft.com/web/webmatrix/)

Contribution
============

If you want to contribute code or get any idea to improve WebCommander,
Please contact Jerry Liu (liuj@vmware.com, Skype: whirls9@hotmail.com).
