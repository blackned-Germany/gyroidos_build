#!/bin/bash
#
# This file is part of GyroidOS
# Copyright(c) 2013 - 2017 Fraunhofer AISEC
# Fraunhofer-Gesellschaft zur Förderung der angewandten Forschung e.V.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2 (GPL 2), as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GPL 2 license for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>
#
# The full GNU General Public License is included in this distribution in
# the file called "COPYING".
#
# Contact Information:
# Fraunhofer AISEC <gyroidos@aisec.fraunhofer.de>
#

# This script creates the general PKI (general root CA, device subCA, backend subCA, user subCA)
# This script furthermore creates the backend certificate
# With the backend subCA, we can create future backend certificates
# With the device subCA, we can sign device CSRs (device provisioning)
# With the user subCA, we can create user tokens (usertoken generator script)
CONFIG_FILE="gen_pki_generator.conf"

# cleanup function for temp files
cleanup(){
  echo "Cleanup unnecessary files"
  [[ -f ${OCSP_SERVER_CSR} ]] && rm ${OCSP_SERVER_CSR}
  # for x in *.pem;do rm $x;done
}

# check for clean directory and existence of req files
check_clean(){
  echo "Check if directory is clean and if required files exist"
  # index files
  # necessary config files
  assert_file_exists ${GEN_ROOTCA_CONFIG}
  assert_file_exists ${DEVICE_SUBCA_CONFIG}
  assert_file_exists ${BACKEND_SUBCA_CONFIG}
  assert_file_exists ${USER_SUBCA_CONFIG}
  assert_file_exists ${BACKEND_CONFIG}
  assert_file_exists ${OCSP_SERVER_CONFIG}
  echo "Successfully found required files in clean directory"
}

# loads parameters and switch between user token and create ca mode
load_parameters(){
  echo "Processing command line arguments"
  if [ $# -eq 0 ]; then
    echo "No options specified. Looking for config in script's folder"
  elif [ $# -gt 4 ]; then
    echo "Too many arguments specified: $# (expected up to 2 option)"
    echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass) <envfile>]"
    exit 1
  fi

  while [[ $# > 1 ]]
  do
    key="$1"
    case $key in
      -c|--config)
        CONFIG_FILE="$2"
      shift
      ;;
      -p|--pass)
	source $2
        PASS_IN="-passin env:GYROIDOS_TEST_PASSWD_PKI"
        PASS_OUT="-passout env:GYROIDOS_TEST_PASSWD_PKI"
      shift
      ;;

      *)
        echo "Invalid option specified (${key}), abort"
        echo "Usage: $0 [(-c|--config) <config_file>] [(-p|--pass) <envfile>]"
        exit 1
      ;;
    esac
    shift
  done
}

### Start of logic ###
load_parameters $@
cd $(dirname $0)
# load config parameters and helper functions
source ${CONFIG_FILE}
echo "Config file is: ${CONFIG_FILE}"
source ${LIB_FILE}
echo "Function lib is: ${LIB_FILE}"
check_clean

# BACKEND CERT
echo "Create Backend CSR"
openssl req -batch -config ${OCSP_SERVER_CONFIG} -newkey rsa-pss -pkeyopt rsa_keygen_bits:${KEY_SIZE} ${PASS_IN} ${PASS_OUT} -out ${OCSP_SERVER_CSR} -outform PEM -nodes
error_check $? "Failed to create OCSP Server CSR"

echo "Sign OCSP Server CSR with backend sub CA certificate"
touch ${BACKEND_SUBCA_INDEX_FILE}
openssl ca -create_serial -batch -config ${BACKEND_SUBCA_CONFIG} -policy signing_policy -extensions signing_req ${PASS_IN} -out ${OCSP_SERVER_CERT} -infiles ${OCSP_SERVER_CSR}
error_check $? "Failed to sign OCSP Server CSR with backend sub CA certificate"

echo "Verify newly created Backend certificate"
openssl verify -CAfile ${GEN_ROOTCA_CERT} -untrusted ${BACKEND_SUBCA_CERT} ${OCSP_SERVER_CERT}
error_check $? "Failed to verify newly signed OCSP Server certificate"

echo "Concatenate gen CA chain to backend cert"
cat ${BACKEND_SUBCA_CERT} >> ${OCSP_SERVER_CERT}

echo "General PKI certificate structure successfully created"
echo "Cleanup temporary files"
cleanup
exit 0
