#!/usr/bin/env bash

# Copyright (c) 2014 Cloudera, Inc. All rights reserved.


# Modified by tarland@trace3.com to work with Centrify
# Trick is to use Centrify for kerberos tools, but
# only use 'openldap-clients' for ldap commands.


set -e
set -x

# Explicitly add Centrify locations to path
export PATH=/usr/share/centrifydc/kerberos/bin:/usr/share/centrifydc/bin:$PATH

# oddly we need ldapsearch from openldap-clients NOT centrify
LDAPSEARCH="/usr/bin/ldapsearch"

KEYTAB_OUT=$1
USER=$2
PASSWD=$3
KVNO=$4

name=`echo $USER | cut -f1 -d"@"`

# Determine if sleep is needed before echoing password.
# This is needed on Centos/RHEL 5 where ktutil doesn't
# accept password from stdin.
SLEEP=0
RHEL_FILE=/etc/redhat-release
if [ -f $RHEL_FILE ]; then
  set +e # Ignore errors in grep
  grep Tikanga $RHEL_FILE
  if [ $? -eq 0 ]; then
    SLEEP=1
  fi
  if [ $SLEEP -eq 0 ]; then
    grep 'CentOS release 5' $RHEL_FILE
    if [ $? -eq 0 ]; then
      SLEEP=1
    fi
  fi
  if [ $SLEEP -eq 0 ]; then
    grep 'Scientific Linux release 5' $RHEL_FILE
    if [ $? -eq 0 ]; then
      SLEEP=1
    fi
  fi
  set -e
fi

if [ -z "$KRB5_CONFIG" ]; then
  echo "Using system default krb5.conf path."
else
  echo "Using custom config path '$KRB5_CONFIG', contents below:"
  cat $KRB5_CONFIG
fi

# Export password to keytab
IFS=' ' read -a ENC_ARR <<< "$ENC_TYPES"
{
  for ENC in "${ENC_ARR[@]}"
  do
    if [ $SLEEP -eq 1 ]; then
      sleep 1
    fi
    echo "$PASSWD"
  done
} | adkeytab --adopt --local -w "$PASSWD" --keytab $KEYTAB_OUT --user $USER $name

chmod 600 $KEYTAB_OUT

# Do a kinit to validate that everything works
kinit -k -t $KEYTAB_OUT $name

# If this is not AD admin account, return from here
if [ "$AD_ADMIN" != "true" ]; then
  exit 0
fi

# With AD do a simple search to make sure everything works.
# Set properties needed for ldapsearch to work.
# Tell GSSAPI not to negotiate a security or privacy layer since
# AD doesn't support nested security or privacy layers
LDAP_CONF=`mktemp /tmp/cm_ldap.XXXXXXXX`
echo "TLS_REQCERT     never" >> $LDAP_CONF
echo "sasl_secprops   minssf=0,maxssf=0" >> $LDAP_CONF

export LDAPCONF=$LDAP_CONF

set +e # Allow failures to SASL so we can see if simple auth works
$LDAPSEARCH -LLL -H "$AD_SERVER" -b "$DOMAIN" "userPrincipalName=$USER"
if [ $? -ne 0 ]; then
  echo "ldapsearch did not work with SASL authentication. Trying with simple authentication"
  $LDAPSEARCH -LLL -H "$AD_SERVER" -b "$DOMAIN" -x -D $USER -w "$PASSWD" "userPrincipalName=$USER"
  if [ $? -ne 0 ]; then
    echo "Failed to do ldapsearch."
    echo "Please make sure Active Directory configuration is correctly specified and LDAP over SSL is enabled."
    exit 1
  fi
  # Simple authentication worked. Store the password in output file.
  echo -n "$PASSWD" > $KEYTAB_OUT
fi
set -e
rm -f $LDAP_CONF

