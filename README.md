CDH-Kerberos-Centrify
=====================

Cloudera's CMF Kerberos scripts adjusted for integration with Centrify AD.


#### Overview

Deploying Kerberos on CDH involves integrating with existing kerberos infrastructure, 
either MIT KDC or Microsoft Active Directory. Centrify provides an AD based solution 
providing improved security and role management, however does not integrate with CDH 
easily out of the box.  

There are a few options for intergrating with Centrify, but by far the path of least 
resistance of enabling kerberos within CDH is to allow Cloudera Manager to manage the 
creation and deletion of all service principals. For this to work as designed with 
Centrify, a few minor changes to Cloudera's scripts are necessary.

This project provides modified CDH scripts for seamlessly supporting use of Centrify 
by Cloudera Manager. 

The needed script changes results from the following issues:

 * MIT Kerberos tools (kinit, etc) do not work with Centrify.
 * Centrify's LDAP tools do not work with CDH's openldap usage.

#### Installation

This approach is for directly attaching the Kerberized cluster to Active Directory 
(ie. no cluster dedicated KDC).  Additionally, this setup assumes the cluster hosts 
have been 'Centrified' and have been provisioned within its own cluster-specific 
Organizational Unit(ou) with an AD User that has create/delete rights to that OU.

When following Cloudera's prerequisites for enabling Kerberos, the MIT krb5 client 
tools should NOT be installed. 

 * RHEL/CentOS package is *krb5-workstation*
 * Ubuntu's package is *krb5-user* 

These packages should be removed if they already exist. The *openldap-clients* 
package should be installed as intended.

Also note that Active Directory creates default principals for a newly provisioned 
OU, such as HTTP, SMB, and NFS. The HTTP principal will absolutely collide with 
Cloudera Manager's attempts to create its own HTTP principals, and should be 
deleted prior to running the CM Kerberos Wizerd. This can be done at the host level,
per host, by running the following priviledged command:

```
adkeytab --delspn --machine --principal http
```

Lastly, once the cluster is ready to be kerberized (via the CM Kerberos Wizard), 
simply replace the scripts in */usr/share/cmf/bin* with the scripts from ./bin/


