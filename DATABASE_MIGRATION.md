# Database Migration Guide for Supabase

This guide outlines the steps to migrate the local JSON Quran database into your live Supabase PostgreSQL database.

---

## 1. Setup the Database Schema

1. Go to your **Supabase Dashboard** -> **SQL Editor**.
2. Click **New query**.
3. Open the file [schema.sql](file:///C:/Users/waverider/.gemini/antigravity/scratch/tafsir-upgrade/schema.sql) in your project, copy the entire SQL script, and paste it into the editor.
4. Click **Run**.
5. Ensure all tables, indexes, and search functions are created successfully.

---

## 2. Prepare Your Environment

On your local machine where you have network access to your Supabase instance, set up your credentials:

1. Create a file named `.env` in the root of the project:
   ```env
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-secret-key
   ```
   > [!IMPORTANT]
   > Use the **service_role** key (found in Supabase under Project Settings -> API) instead of the `anon` key. The service role key bypasses Row-Level Security, allowing the script to write all Quran records efficiently. Do not commit your `.env` file to git.

---

## 3. Run the Migration Script

Run the migration script using Python (no third-party dependencies are required as the script uses standard Python libraries):

```bash
# Execute the script
python scripts/migrate.py
```

The script will:
- Parse all `sura_list.json` entries and populate `surahs`.
- Populate Arabic texts in `verses`.
- Loop through all 111 translations and upload to `translations` in batches of 1,000.
- Loop through all 14 tafsirs and upload to `tafsirs` in batches of 1,000.
- Loop through Asbabun Nuzul files and upload to `asbabun_nuzul`.
- Load English and Indonesian topic tags and tag mappings.

---

## 4. Querying the Database

Once the migration is complete, you can test the queries directly in your Supabase SQL Editor:

### Exact Word Search
```sql
-- Search for translations matching the exact word "air" in English
select * from search_exact_word('air', 'en');
```

### Get Verses by Topic Tag
```sql
-- Get verses mapped to the topic "iman" with the Indonesian Kemenag translation
select * from get_verses_by_tag('iman', 'id.kemenag');
```
