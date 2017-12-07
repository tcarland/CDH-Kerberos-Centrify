#!/usr/bin/env bash

# Copyright (c) 2011 Cloudera, Inc. All rights reserved.

# Modified by tarland@trace3.com to work with Centrify
# Trick is to use Centrify for kerberos tools, but
# only use 'openldap-clients' for ldap commands.

set -e
set -x

# Explicitly add Centrify locations to path
export PATH=/usr/share/centrifydc/kerberos/bin:/usr/share/centrifydc/bin:$PATH


KTUTIL_BIN=/usr/share/centrifydc/kerberos/sbin/ktutil
TGTPATH=/var/run/cloudera-scm-server/merged


KEYTAB_OUT=$1
shift

$KTUTIL_BIN <<EOF
$(for KEYTAB_IN in "$@"; do echo "rkt $KEYTAB_IN"; done)
wkt $KEYTAB_OUT
EOF

chmod 600 $KEYTAB_OUT 

