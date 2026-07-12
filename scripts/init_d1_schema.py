#!/usr/bin/env python3
"""Initialize a Cloudflare D1 database from a schema.sql file via the REST API.

Use this when `wrangler d1 execute` is impractical (e.g. behind a 30s-limited
credential runner). The D1 /query endpoint accepts the WHOLE multi-statement SQL
in one POST and returns one result-group per statement.

Usage:
  CF_API_TOKEN=<token> CF_ACCOUNT_ID=<acct> \\
  python3 init_d1_schema.py <database_id> path/to/schema.sql
"""
import json, os, sys, urllib.request

ACCOUNT = os.environ["CF_ACCOUNT_ID"]
TOKEN = os.environ["CF_API_TOKEN"]
DB = sys.argv[1]
SCHEMA = sys.argv[2]

with open(SCHEMA) as f:
    sql = f.read()

url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT}/d1/database/{DB}/query"
headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
req = urllib.request.Request(url, data=json.dumps({"sql": sql}).encode(), headers=headers, method="POST")
with urllib.request.urlopen(req, timeout=30) as r:
    d = json.loads(r.read())
if not d.get("success"):
    sys.exit(f"schema init failed: {d.get('errors')}")
groups = d.get("result")
n = len(groups) if isinstance(groups, list) else 1
print(f"schema OK — {n} statement group(s) executed")

# verify tables
req2 = urllib.request.Request(
    url,
    data=json.dumps({"sql": "SELECT count(*) c FROM sqlite_master WHERE type='table';"}).encode(),
    headers=headers, method="POST")
with urllib.request.urlopen(req2, timeout=30) as r:
    d2 = json.loads(r.read())
print("tables:", d2["result"][0]["results"][0]["c"])
