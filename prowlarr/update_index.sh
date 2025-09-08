#!/usr/bin/env bash

HOST="prowlarr.default.k8s.home.netfront.io"
PROWLARR_API_KEY=""


curl -s -o ./prowlarr-indexers.json  https://raw.githubusercontent.com/mhdzumair/MediaFusion/main/resources/json/prowlarr-indexers.json 

INDEXERS=$(jq -c '.[]' ./prowlarr-indexers.json)
echo "$INDEXERS" | while read -r indexer; do
  indexer_name=$(echo "$indexer" | jq -r '.name')
  echo "Adding indexer named: $indexer_name"

  curl -X POST -H "Content-Type: application/json" -H "X-API-KEY: $PROWLARR_API_KEY" -d "$indexer" "http://$HOST:9696/api/v1/indexer"
done

rm ./prowlarr-indexers.json
