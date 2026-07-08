import os
from supabase import create_client, Client

url = "https://kcvpyhdbmoxxpsqghmrf.supabase.co"
# Let's read the key from lib/core/config.dart or environment
# Let's inspect config.dart to get key
with open("lib/core/config.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Extract supabaseKey
import re
key_match = re.search(r"supabaseKey\s*=\s*'([^']+)'", text)
anon_key = key_match.group(1) if key_match else ""

supabase: Client = create_client(url, anon_key)

# We can query settings or run an RPC if one is available to run sql,
# but we don't have a direct sql execution RPC unless we check one.
# Let's check what RPCs are available in scripts/rpc_functions.sql
print("Supabase URL:", url)
print("Anon Key Length:", len(anon_key))
