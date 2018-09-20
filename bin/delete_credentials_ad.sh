#!/usr/bin/env bash

# Copyright (c) 2017 Cloudera, Inc. All rights reserved.

# Modified by tarland@trace3.com to work with Centrify
# Trick is to use Centrify for kerberos tools, but
# use 'openldap-clients' for ldap commands.

set -e
set -x

# Explicitly add Centrify locations to path
export PATH=/usr/share/centrifydc/kerberos/bin:/usr/share/centrifydc/bin:$PATH

# Force use of openldap-clients
LDAPSEARCH="/usr/bin/ldapsearch"
LDAPDELETE="/usr/bin/ldapdelete"


PRINC=$1

if [ -z "$KRB5_CONFIG" ]; then
  echo "Using system default krb5.conf path."
else
  echo "Using custom config path '$KRB5_CONFIG', contents below:"
  cat $KRB5_CONFIG
fi

SIMPLE_PWD_STR=""
if [ "$SIMPLE_AUTH_PASSWORD_KEY" = "" ]; then
  kinit -k -t $CMF_KEYTAB_FILE $CMF_PRINCIPAL
else
  SIMPLE_PWD_STR="-x -D $CMF_PRINCIPAL -w $SIMPLE_AUTH_PASSWORD_KEY"
fi

# Set properties needed for ldapdelete to work.
# Tell GSSAPI not to negotiate a security or privacy layer since
# AD doesn't support nested security or privacy layers
LDAP_CONF=`mktemp /tmp/cm_ldap.XXXXXXXX`
echo "TLS_REQCERT     never" >> $LDAP_CONF
echo "sasl_secprops   minssf=0,maxssf=0" >> $LDAP_CONF

export LDAPCONF=$LDAP_CONF

PRINC_SEARCH=`$LDAPSEARCH -LLL -H "$AD_SERVER" -b "$DOMAIN" $SIMPLE_PWD_STR "userPrincipalName=$PRINC"`

# Unwrap lines that ldapsearch wrapped
RESULTS_UNWRAPPED=$(echo "$PRINC_SEARCH" | sed -n "1 {h; $ !d}; $ {x; s/\n //g; p}; /^ / {H; d}; /^ /! {x; s/\n //g; p}")

echo “$RESULTS_UNWRAPPED”

set +e # Allow non-zero return from grep

echo $PRINC_SEARCH | grep -q userPrincipalName
if [ $? -eq 0 ]; then
  echo "Deleting $PRINC from Active Directory."
  for ACC_CN_VAL in "$(echo "$RESULTS_UNWRAPPED" | grep dn | awk -F ": " '$1 == "dn" {print $2}')";
  do
    echo $ACC_CN_VAL
    $LDAPDELETE -H "$AD_SERVER" $SIMPLE_PWD_STR "$ACC_CN_VAL"
    if [ $? -ne 0 ]; then
      echo "Deletion of the Active Directory account $PRINC failed."
      exit 1
    fi
  done
else
  echo "Active directory account $PRINC not found. Nothing to delete."
fi

rm -f $LDAP_CONF
