#!/bin/bash 

########################################################
# set a secret in a key vault
# Example:
#    setsecret <secret name> <vault name> <secret value>
########################################################
function setsecret {
  echo "Created secret with id $(az keyvault secret set -n $1 --vault-name $2 --value $3 --query id)"
}

########################################################
# write random string to STDOUT
# Example:
#    randomstring <length of string>
########################################################
function randomstring {
  cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9!"#$%&'\''()*+,-./:;<=>?[\]^_`{|}~' | fold -w $1 | head -n 1
}
