# Cloudflare Traffic by Account & Zone
This script will pull various metrics from Cloudflare's GraphQL API by Account and Zone Name
- Egress Bytes
- Cached Egress Bytes
- Cached Requests
- Encryptes Bytes
- Encrypted Requests
- Page Views
- Requests

The script will generate a CSV using the fields above, plus
- Account name
- Zone name

### Authentication
Authenticate against the GraphQL API by exporting your Cloudflare Email and global API token
```
export CLOUDFLARE_API_KEY=<your API token>
export CLOUDFLARE_EMAIL=<your Email>
```

### Run the script

`./traffic.sh 2020-07-01 2020-07-31`

to pull usage metrics from the 1st to the 31st of July 2020

### Additional requirements

- `jq` command
