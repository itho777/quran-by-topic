from supabase import create_client

url = 'https://zgeygoclduqotqveperx.supabase.co'
key = 'sb_publishable_kyxOvxsj6WxjTCadR_tpoA_Xb7sQ6Ik'

supabase = create_client(url, key)

res = supabase.rpc('search_verses', {
    'query': 'jalalayn',
    'lang_code': 'id',
    'result_limit': 5,
    'offset_val': 0
}).execute()

print("Search response:")
for r in res.data:
    print("-" * 50)
    print("verse_key:", r.get('verse_key'))
    print("match_note:", r.get('match_note'))
    print("context_snippet:", r.get('context_snippet'))
