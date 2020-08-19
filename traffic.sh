#!/bin/bash
set -e

# Trapping SIGTERM
trap "exit 1" TERM

# Used in functions to stop execution on error
export SCIPRT_PID=$$

# Exits program with a message sent to stderr
function exit_with_error {
  >&2 echo "$1"
  kill -s TERM $SCIPRT_PID
}

# Pull accounts by API Key
function get_accounts {
  data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts?page=1&per_page=50" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")
  success=$(echo "$data" | jq -r '.success')

  if [ "$success" != "true" ]; then
    exit_with_error "error reading accounts: $(echo "$data" | jq -r '.errors')"
  fi

  accountTags=$(echo "$data" | jq -r '.result[] | "\(.id)#\(.name)"')
  echo "$accountTags"
}

# Pull zones by Account ID
function get_zones {
  data=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?&account.id=$1&page=1&per_page=1000" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")
  success=$(echo "$data" | jq -r '.success')

  if [ "$success" != "true" ]; then
    exit_with_error "error reading zones: $(echo "$data" | jq -r '.errors')"
  fi

  zoneTags=$(echo "$data" | jq -r '.result[] | "\(.id)#\(.name)"')
  echo "$zoneTags"
}

# Pull egress bytes per zoneTag
function get_traffic {
  data=$(curl -s "https://api.cloudflare.com/client/v4/graphql" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    --data-binary '{"operationName":"GetHeadlineStats","variables":{"zoneTag":"'"$1"'","limit":10000,"filter":{"date_geq":"'"$2"'","date_leq":"'"$3"'"}},"query":"query GetHeadlineStats {\n  viewer {\n    zones(filter: {zoneTag: $zoneTag}) {\n      total: httpRequests1dGroups(filter: $filter, limit: $limit) {        uniq {\n          uniques\n          __typename\n        }\n        __typename\n      }\n      statsOverTime: httpRequests1dGroups(filter: $filter, limit: $limit) {\n        sum {\n          requests\n          bytes\n          pageViews\n          cachedRequests\n          cachedBytes\n          encryptedRequests\n          encryptedBytes\n          responseStatusMap {\n            edgeResponseStatus\n            requests\n            __typename\n          }\n          __typename\n        }\n        uniq {\n          uniques\n          __typename\n        }\n                __typename\n      }\n            __typename\n    }\n    __typename\n  }\n}\n"})')

  errors=$(echo "$data" | jq -r '.errors')

  if [ "$errors" != "null" ]; then
    exit_with_error "error reading zone traffic: $(echo "$data" | jq -r '.errors')"
  fi

  bytes=$(echo "$data" | jq -r '.data.viewer.zones[].statsOverTime[].sum | "\(.bytes);\(.cachedBytes);\(.cachedRequests);\(.encryptedBytes);\(.encryptedRequests);\(.pageViews);\(.requests)"')
  echo "$bytes"
}

# checking environment variables
[ -z "$CLOUDFLARE_EMAIL" ] && exit_with_error "CLOUDFLARE_EMAIL is not set"
[ -z "$CLOUDFLARE_API_KEY" ] && exit_with_error "CLOUDFLARE_API_KEY is not set"
if [ "$#" -ne 2 ]; then
  exit_with_error "Run script with date range arguments, for example: [2020-07-01] [2020-07-31] (data will include the respective days)"
fi

for date in "$@"
do
  if [[ $OSTYPE =~ "darwin" ]]; then
    date -jf "%Y-%m-%d" "$date" +"%Y-%m-%d" >/dev/null
  else
    date "+%Y-%m-%d" -d "$date" >/dev/null
  fi
  if [ "$?" -ne 0 ]; then
    exit_with_error "Dates must be passed in format YYYY-MM-DD"
  fi
done

# Pulling all account tags that the user has access to
accounts=$(get_accounts)

echo "Account Name;Zone Name;Bytes;CachedBytes;CachedRequests;EncryptedBytes;EncryptedRequests;PageViews;Requests"
while read -r account
do
  IFS='#' read -r -a accountInfo <<< "$account"

  while read -r zone
  do
    IFS='#' read -r -a zoneInfo <<< "$zone"
    if [ -n "${zoneInfo[0]}" ]; then
      echo "${accountInfo[1]};${zoneInfo[1]};$(get_traffic "${zoneInfo[0]}" "$1" "$2")"
    fi

  done <<< "$(get_zones "${accountInfo[0]}")"
done <<< "$accounts"
