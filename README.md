CDH-Kerberos-Centrify
=====================

Cloudera's CMF Kerberos scripts modified for integration with Centrify AD.


#### Overview

Deploying Kerberos on Cloudera CDH involves integrating with existing kerberos
infrastructure. CDH supports either MIT KDC or Microsoft Active Directory.
Centrify is an Identity and Access Managemenent solution that provides an
Active Directory integrated solution offering improved security and access
role management. Wheras CDH supports Microsoft Active Directory, Centrify has a
few nuances that does not work with Cloudera Manager's Kerberos scripts.

There are a few alternate options for configuring Kerberos in CDH with Centrify,
but the path of least resistance is to allow Cloudera Manager to manage the
creation and deletion of all service principals via the Kerberos Wizard.
For this to work as designed with Centrify, a few minor changes to Cloudera's
kerberos scripts are needed.

This project provides the modified Cloudera scripts for supporting the use of
Centrify with Cloudera Manager, tested against versions 5.12 through 5.15.

The needed script changes result primarily from the following:
* MIT Kerberos tools (kinit, ktutil, etc) do not work with Centrify.
* Centrify's LDAP tools are not compatible with CDH's *OpenLDAP* usage.


#### Installation

This approach is for attaching a Kerberized cluster directly to Active Directory
(ie. no cluster dedicated KDC).  Additionally, this setup assumes the cluster hosts
have been *Centrified* and have been provisioned within its own cluster specific
Organizational Unit (ou) with an AD User that has administrative create/delete
rights to that OU.

When following Cloudera's prerequisites for enabling Kerberos, the MIT krb5 client
tools should NOT be installed as requested.
* The RHEL/CentOS package is *krb5-workstation*
* Ubuntu's package is *krb5-user*

These packages should be removed if they already exist. Additionally, while Centrify
installations add some of its own tools to the system path, ensure the Kerberos
tools (commonly /usr/share/centrify/kerberos) are also on the system path (this
is often configured). Essentially, `which kinit` should resolve to the Centrify
version. Given the importance of users needing the right kinit, it likely
wouldn't hurt to simply add a link for */bin/kinit* to Centrify's version.

Per Cloudera's documentation, the *openldap-clients* package should be installed as
Centrify's OpenLDAP tools do not work with the scripts. The versions provided here
explicitly use the OpenLDAP binary out of /usr/bin.

Additionally, it is important to note that Centrify creates a few default
principals for a newly provisioned OU, such as HTTP, CIFS, and NFS. The HTTP
principal will **absolutely** collide with Cloudera Manager's attempts to create
its own HTTP principals. Prior to starting the Kerberos process, the HTTP
principal should be deleted. This can be done on the hosts, per host, by running
the following privileged command:
```
# adkeytab --delspn --machine --principal http
```

Lastly, once the cluster is ready to be Derberized (via the CM Kerberos Wizard),
replace the scripts in */usr/share/cmf/bin* on the Cloudera Manager host(s) with
the scripts from *./bin/*
