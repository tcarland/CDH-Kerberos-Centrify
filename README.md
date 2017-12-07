CDH-Kerberos-Centrify
=====================

Cloudera's CMF Kerberos scripts adjusted for integration with Centrify AD.


#### Overview

Deploying Kerberos on CDH involves integrating with existing Kerberos Infrastructure, either MIT KDC 
or Microsoft Active Directory. Centrify provides an AD based solution providing improved 
security and role management, however does not integrate with CDH easily out of the box. This project 
provides modified CDH scripts for seamlessly supporting use of Centrify by Cloudera Manager. 

A few of the required changes results from the following:

 * MIT Kerberos tools (kinit, etc) do no work with Centrify.
 * Centrify's ldap tools do not work with CDH's openldap usage.

#### Installation

This approach is for directly attaching the Kerberized cluster to Active Directory (ie. no cluster 
dedicated KDC).  Additionally, this setup assumes the cluster hosts have been 'Centrified' and 
have been provisioned within its own Organizational Unit(ou) with an AD User that has 
create/delete rights to that OU.

When following Cloudera's prerequisites for enabling Kerberos, the MIT krb5 client tools 
should NOT be installed. 

 * RHEL/CentOS package is *krb5-workstation*
 * Ubuntu's package is *krb5-user* 

These packages should be removed if they already exist. The *openldap-clients* package should be 
installed as intended.

Lastly, once the cluster is ready to be kerberized (via the CM Kerberos Wizard), simply replace the 
scripts in */usr/share/cmf/bin* with the scripts from ./bin/




