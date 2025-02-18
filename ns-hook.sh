#!/usr/bin/env bash

deploy_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called once for every domain that needs to be
    # validated, including any alternative names you may have listed.
    #
    # Parameters:
    # - DOMAIN
    #   The domain name (CN or subject alternative name) being
    #   validated.
    # - TOKEN_FILENAME
    #   The name of the file containing the token to be served for HTTP
    #   validation. Should be served by your web server as
    #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
    # - TOKEN_VALUE
    #   The token value that needs to be served for validation. For DNS
    #   validation, this is what you want to put in the _acme-challenge
    #   TXT record. For HTTP validation it is the value that is expected
    #   be found in the $TOKEN_FILENAME file.
    counter_curr=$(< "$counter_file" )
    connect=$(< "$connect_file" )
    if [ $connect == "1" ]
    then
      /root/ns-letsencrypt/ns-copytons.py challenge $TOKEN_FILENAME $TOKEN_VALUE $DOMAIN $counter_curr
      (( ++counter_curr ))
      printf '%s\n' "$counter_curr" >"$counter_file"
    else
      echo "Can't connect.  Skipping challenge"
    fi
}

clean_challenge() {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.
    connect=$(< "$connect_file" )
    if [ $connect == "1" ]
    then
	  /root/ns-letsencrypt/ns-copytons.py clean $DOMAIN
	else
      echo "Can't connect.  Skipping clean"
    fi
}

deploy_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
    # - TIMESTAMP
    #   Timestamp when the specified certificate was created.
    connect=$(< "$connect_file" )
	if [ $connect == "1" ]
    then 
	  /root/ns-letsencrypt/ns-copytons.py save $CERTFILE $KEYFILE $CHAINFILE $DOMAIN
	else
      echo "Can't connect.  Skipping deploy"
    fi
}

unchanged_cert() {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
}

invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"

    # This hook is called if the challenge response has failed, so domain
    # owners can be aware and act accordingly.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - RESPONSE
    #   The response that the verification server returned
}

request_failure() {
    local STATUSCODE="${1}" REASON="${2}" REQTYPE="${3}"

    # This hook is called when an HTTP request fails (e.g., when the ACME
    # server is busy, returns an error, etc). It will be called upon any
    # response code that does not start with '2'. Useful to alert admins
    # about problems with requests.
    #
    # Parameters:
    # - STATUSCODE
    #   The HTML status code that originated the error.
    # - REASON
    #   The specified reason for the error.
    # - REQTYPE
    #   The kind of request that was made (GET, POST...)
}

exit_hook() {
  # This hook is called at the end of the cron command and can be used to
  # do some final (cleanup or other) tasks.
  /root/ns-letsencrypt/ns-copytons.py saveconfig
  rm -rf /root/ns-letsencrypt/.connect*
  rm -rf /root/ns-letsencrypt/.counter*
}

startup_hook() {
  # This hook is called before the cron command to do some initial tasks
  # (e.g. starting a webserver).
  echo Testing Netscaler Connectivity
  /root/ns-letsencrypt/ns-copytons.py test
  ret=$?
  if [ $ret -ne 0 ]
  then
     echo "Problems connecting to Netscaler"
  else
     printf '%s\n' "1" >"$connect_file"
     printf '%s\n' "0" >"$counter_file"
     /root/ns-letsencrypt/ns-copytons.py SetHAPrimaryInConfig
  fi
}

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|unchanged_cert|invalid_challenge|request_failure|startup_hook|exit_hook)$ ]]; then
  "$HANDLER" "$@"
fi
