#!/usr/bin/env bash

# Copyright (c) 2014 Cloudera, Inc. All rights reserved.

# Modified by Timothy C. Arland <tarland@trace3.com>
#  Dec 2017, to work with Centrify
# Trick is to use Centrify for kerberos tools, but
# only use 'openldap-clients' for ldap commands.

set -e
set -x

# Explicitly add Centrify locations to path
export PATH=/usr/share/centrifydc/kerberos/bin:/usr/share/centrifydc/bin:$PATH

# oddly we need ldapsearch from openldap-clients NOT centrify
LDAPSEARCH="/usr/bin/ldapsearch"
LDAPMODIFY="/usr/bin/ldapmodify"
LDAPDELETE="/usr/bin/ldapdelete"

KEYTAB_OUT=$1
PRINC=$2
USER=$3
PASSWD=$4
DELETE_ON_REGENERATE=$5
SET_ENCRYPTION_TYPES=$6
ENC_TYPES_MASK=$7
USERACCOUNTCONTROL=$8
ACCOUNTEXPIRES=$9
OBJECTCLASSES=${10}

DIST_NAME="CN=$USER,$DOMAIN"
name=`echo $PRINC | cut -f1 -d"@"`

echo "$name"

if [ -z "$KRB5_CONFIG" ]; then
  echo "Using system default krb5.conf path."
else
  echo "Using custom config path '$KRB5_CONFIG', contents below:"
  cat $KRB5_CONFIG
fi

SIMPLE_PWD_STR=""
if [ "$SIMPLE_AUTH_PASSWORD_KEY" = "" ]; then
  cmf_name=`echo $CMF_PRINCIPAL | cut -f1 -d"@"`
  echo "cmf keytab: $CMF_KEYTAB_FILE"
  kinit -k -t $CMF_KEYTAB_FILE $cmf_name
else
  SIMPLE_PWD_STR="-x -D $CMF_PRINCIPAL -w $SIMPLE_AUTH_PASSWORD_KEY"
fi

# Set properties needed for ldapmodify to work.
# Tell GSSAPI not to negotiate a security or privacy layer since
# AD doesn't support nested security or privacy layers
LDAP_CONF=`mktemp /tmp/cm_ldap.XXXXXXXX`
echo "TLS_REQCERT     never" >> $LDAP_CONF
echo "sasl_secprops   minssf=0,maxssf=0" >> $LDAP_CONF

export LDAPCONF=$LDAP_CONF

# AD lets you create multiple accounts with same principal
# as long as distinguished name is unique. So we should check
# if the principal already exists and let user know about it.

PRINC_SEARCH=`/usr/bin/ldapsearch -LLL -H "$AD_SERVER" -b "$DOMAIN" $SIMPLE_PWD_STR "userPrincipalName=$PRINC"`

# Unwrap the lines that ldapsearch wrapped for whatever reason
# Use sed :
# { and } are used for command grouping - ; is the command delimiter. The sed command below is
# 4 separate address/command pairs.
# 1 {h; $ !d}; ----On the first line, store the line in the hold buffer. If this is not the last line,
# delete it, and go to the next line. If it is the last line, it will fall through to the next statement $ ....
# This (with sed -n) supresses printing the first line.
# $ {x; s/\n //g; p}; ----On the last line, swap the hold buffer into the current pattern buffer.
# Delete all (/g) occurances of newline+space in the current pattern buffer. Print the current pattern buffer.
# /^ / {H; d}; ----If the line is a continuation line, just add it to the hold space, delete it, and go to the next line.
# /^ /! {x; s/\n //g; p} ----If the line is not a continuation line, swap the hold buffer with the current pattern buffer.
# Delete all (/g) occurances of newline+space in the current pattern buffer. Print the current pattern buffer.
RESULTS_UNWRAPPED=$(echo "$PRINC_SEARCH" | sed -n "1 {h; $ !d}; $ {x; s/\n //g; p}; /^ / {H; d}; /^ /! {x; s/\n //g; p}")
echo “$RESULTS_UNWRAPPED”

set +e # Allow non-zero return from grep

echo $PRINC_SEARCH | grep -q userPrincipalName
if [ $? -eq 0 ]; then
  if [ "$DELETE_ON_REGENERATE" = "false" ]; then
    echo "$PRINC already exists in Active Directory. Please delete it before re-generating it from Cloudera Manager."
    echo "Or set the AD_DELETE_ON_REGENERATE configuration option to automatically delete the accounts" \
        "and proceed with regeneration."
    exit 1
  fi
  echo "$PRINC already exists in Active Directory. Deleting before re-generating it from Cloudera Manager."
  for ACC_CN_VAL in "$(echo "$RESULTS_UNWRAPPED" | grep dn | awk -F ": " '$1 == "dn" {print $2}')";
  do
    echo $ACC_CN_VAL
    $LDAPDELETE -H "$AD_SERVER" $SIMPLE_PWD_STR "$ACC_CN_VAL"
    if [ $? -ne 0 ]; then
      echo "Deletion of the Active Directory account $PRINC failed."
      exit 1
    fi
  done
fi

# Add account in AD
# servicePrincipalName is obtained from $PRINC by removing "@REALM" from the end.
# password needs to be specified in unicode using "iconv"
# account is set to never expire by setting accountExpires to 0
# If SET_ENCRYPTION_TYPES is set to true, then pass in msds-supportedEncryptionTypes
# and the associated userAccountControl obtained from the CM server. If not,
# pass in the default value for userAccountControl : 66048 which is obtained by adding
# 512 (for "normal" account) and 65536 (password never expires)
set -e
if [ "$SET_ENCRYPTION_TYPES" = "true" ]; then
$LDAPMODIFY -H "$AD_SERVER" $SIMPLE_PWD_STR <<-%EOF
dn: $DIST_NAME
changetype: add
$(echo "$OBJECTCLASSES" | sed '/str/d')
distinguishedName: $DIST_NAME
sAMAccountName: $USER
servicePrincipalName: $(echo $PRINC | sed -e "s/\@$CMF_REALM//g")
userPrincipalName: $PRINC
unicodePwd:: `echo -n "\"$PASSWD\"" | iconv -f UTF8 -t UTF16LE| base64 -w 0`
accountExpires: $ACCOUNTEXPIRES
userAccountControl: $USERACCOUNTCONTROL
msds-supportedEncryptionTypes: $ENC_TYPES_MASK
%EOF
else
$LDAPMODIFY -H "$AD_SERVER" $SIMPLE_PWD_STR <<-%EOF
dn: $DIST_NAME
changetype: add
$(echo "$OBJECTCLASSES" | sed '/str/d')
distinguishedName: $DIST_NAME
sAMAccountName: $USER
servicePrincipalName: $(echo $PRINC | sed -e "s/\@$CMF_REALM//g")
userPrincipalName: $PRINC
unicodePwd:: `echo -n "\"$PASSWD\"" | iconv -f UTF8 -t UTF16LE| base64 -w 0`
accountExpires: $ACCOUNTEXPIRES
userAccountControl: 66048
%EOF
fi

rm -f $LDAP_CONF

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

# SLEEP=1 is probably a good idea with Centrify. SLEEP=25 was needed for 
# Azure-based deployment with on-prem Centrify


## Modified to use centrify 'adkeytab'
#
# Export password to keytab
IFS=' ' read -a ENC_ARR <<< "$ENC_TYPES"
{
  for ENC in "${ENC_ARR[@]}"
  do
    echo "$PASSWD"
  done
} | adkeytab --adopt --local -w "$PASSWD" --keytab $KEYTAB_OUT --user $name $USER

chmod 600 $KEYTAB_OUT

