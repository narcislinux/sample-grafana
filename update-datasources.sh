#!/bin/bash

# Updates local datasource configurations by retrieving
# the new version from a Grafana instance.
#
# The script assumes that basic authentication is configured
# (change the login credentials with `LOGIN`).
#
# DATASOURCE_DIRECTORY represents the path to the directory
# where the JSON files corresponding to the datasources exist.
# The default location is relative to the execution of the
# script.
#
# URL specifies the URL of the Grafana instance.
#

set -o errexit

readonly URL=${URL:-"http://localhost:3000"}
readonly LOGIN=${LOGIN:-"admin:admin"}
readonly DATASOURCES_DIRECTORY=${DATASOURCES_DIRECTORY:-"grafana/provisioning/datasources/"}


main() {
  local datasources=$(list_datasources)
  local datasource_json

  show_config

  for datasource in $datasources; do
    datasource_json=$(get_datasource "$datasource")

    if [[ -z "$datasource_json" ]]; then
      echo "ERROR:
  Couldn't retrieve datasource $datasource.
      "
      exit 1
    fi
	
    echo "
# config file version
apiVersion: 1
#deleteDatasources:
datasources:
- name: $(echo $datasource_json | jq '.name')
  type: $(echo $datasource_json | jq '.type')
  access: $(echo $datasource_json | jq '.access')
  orgId: $(echo $datasource_json | jq '.orgId')
  url: $(echo $datasource_json | jq '.url')
  password: $(echo $datasource_json | jq '.passworld')
  user: $(echo $datasource_json | jq '.user')
  database: $(echo $datasource_json | jq '.database')
  basicAuth: $(echo $datasource_json | jq '.basicAuth')
  basicAuthUser: $(echo $datasource_json | jq '.basicAuthUser')
  basicAuthPassword: $(echo $datasource_json | jq '.basicAuthPassword')
  withCredentials: $(echo $datasource_json | jq '.withCredentials')
  isDefault:
  jsonData:
     graphiteVersion: "1.1"
     tlsAuth: false
     tlsAuthWithCACert: false
  secureJsonData:
    tlsCACert: "..."
    tlsClientCert: "..."
    tlsClientKey: "..."
  version: 1
  editable: true " > "$DATASOURCES_DIRECTORY$datasource.yml"
  done
}


# Shows the global environment variables that have been configured
# for this run.
show_config() {
  echo "INFO:
  Starting datasource extraction.
  
  URL:                  $URL
  LOGIN:                $LOGIN
  DATASOURCES_DIRECTORY: $DATASOURCES_DIRECTORY
  "
}


# Retrieves a datasource ($1) from the database of datasources.
#
# As we're getting it right from the database, it'll contain an `id`.
#
# Given that the ID is potentially different when we import it
# later, to be make this datasource importable we make the `id`
# field NULL.
get_datasource() {
  local datasource=$1

  if [[ -z "$datasource" ]]; then
    echo "ERROR:
  A datasource must be specified.
  "
    exit 1
  fi

  curl \
    --silent \
    --user "$LOGIN" \
    $URL/api/datasources/$datasource |
    jq '.' 
}


# lists all the datasources available.
#
# `/api/search` lists all the datasources and folders
# that exist under our organization.
#
# Here we filter the response (that also contain folders)
# to gather only the name of the datasources.
list_datasources() {
  curl \
    --silent \
    --user "$LOGIN" \
    $URL/api/datasources |
    jq -r '.[] | .id' |
    cut -d '/' -f2
}

main "$@"
