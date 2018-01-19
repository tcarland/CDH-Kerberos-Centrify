CDH-Kerberos-Centrify
=====================

Cloudera's CMF Kerberos scripts adjusted for integration with Centrify AD.


#### Overview

Deploying Kerberos on CDH involves integrating with existing kerberos infrastructure, 
either MIT KDC or Microsoft Active Directory. Centrify is an Identity and Access 
Managemenent solution that provides an Active Directory based solution providing 
improved security and access role management. However, while CDH supports Microsoft 
Active Directory, Centrify has a few nuances that does not work with Cloudera 
Manager's Kerberos wizard. 

There are a few options for configuring Kerberos in CDH with Centrify, but certainly
the path of least resistance is to allow Cloudera Manager to manage the 
creation and deletion of all service principals via the Kerberos Wizard. 
For this to work as designed with Centrify, a few minor changes to Cloudera's kerberos 
scripts are needed.

This project provides modified CDH scripts for supporting use of Centrify 
by Cloudera Manager 5.12 (and 13) and the Kerberos Wizard.  

The needed script changes result from the following issues:

 * MIT Kerberos tools (kinit, etc) do not work with Centrify.
 * Centrify's LDAP tools do not work with CDH's openldap usage.


#### Installation

This approach is for attaching a Kerberized cluster directly to Active Directory 
(ie. no cluster dedicated KDC).  Additionally, this setup assumes the cluster hosts 
have been 'Centrified' and have been provisioned within its own cluster-specific 
Organizational Unit(ou) with an AD User that has create/delete rights to that OU.

When following Cloudera's prerequisites for enabling Kerberos, the MIT krb5 client 
tools should NOT be installed as requested. 

 * RHEL/CentOS package is *krb5-workstation*
 * Ubuntu's package is *krb5-user* 

These packages should be removed if they already exist. Additionally, while Centrify
installations add some of its own tools to the system path, ensure the kerberos tools
(commonly /usr/share/centrify/kerberos) are also on the system path.

Per Cloudera's documentation, the *openldap-clients* package should be installed as
Centrify's openldap tools do not work with the scripts. The versions provided here
have hardcoded the openldap binary, which probably is not the best choice, but does 
the job.

Also note that Active Directory creates default principals for a newly provisioned 
OU, such as HTTP, SMB, and NFS. The HTTP principal will absolutely collide with 
Cloudera Manager's attempts to create its own HTTP principals, and should be 
deleted prior to running the CM Kerberos Wizerd. This can be done at the host level,
per host, by running the following priviledged command:

```
# adkeytab --delspn --machine --principal http
```

Lastly, once the cluster is ready to be kerberized (via the CM Kerberos Wizard), 
replace the scripts in */usr/share/cmf/bin* with the scripts from *./bin/*


