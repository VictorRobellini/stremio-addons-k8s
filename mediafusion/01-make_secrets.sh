#!/usr/bin/env bash

# Generate a random 32-character string for the SECRET_KEY
SECRET_KEY=$(openssl rand -hex 16)

# Generate a random API key for Prowlarr
PROWLARR_API_KEY=$(openssl rand -hex 16)

# Set a password to secure the API endpoints
API_PASSWORD=$(openssl rand -hex 16)

# If using Premiumize, fill in your OAuth client ID and secret. Otherwise, leave these empty.
# You can obtain OAuth credentials from the https://www.premiumize.me/registerclient with free user account.
PREMIUMIZE_OAUTH_CLIENT_ID=""
PREMIUMIZE_OAUTH_CLIENT_SECRET=""

if [ -z "$API_PASSWORD" ]; then
  echo "Variable API_PASSWORD is empty, exiting."
  exit 1
fi

kubectl create secret generic mediafusion-secrets \
    --from-literal=SECRET_KEY=$SECRET_KEY \
    --from-literal=API_PASSWORD=$API_PASSWORD \
    --from-literal=PROWLARR_API_KEY=$PROWLARR_API_KEY \
    --from-literal=PREMIUMIZE_OAUTH_CLIENT_ID=$PREMIUMIZE_OAUTH_CLIENT_ID \
    --from-literal=PREMIUMIZE_OAUTH_CLIENT_SECRET=$PREMIUMIZE_OAUTH_CLIENT_SECRET || { exit 1; }

echo --
echo -- $(date) >> ./secrets.txt
echo SECRET_KEY=$SECRET_KEY >> ./secrets.txt
echo API_PASSWORD=$API_PASSWORD >> ./secrets.txt
echo PROWLARR_API_KEY=$PROWLARR_API_KEY >> ./secrets.txt
echo PREMIUMIZE_OAUTH_CLIENT_ID=$PREMIUMIZE_OAUTH_CLIENT_ID >> ./secrets.txt
echo PREMIUMIZE_OAUTH_CLIENT_SECRET=$PREMIUMIZE_OAUTH_CLIENT_SECRET >> ./secrets.txt
echo -- >> ./secrets.txt
