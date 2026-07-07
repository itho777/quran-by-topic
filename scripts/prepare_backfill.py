import os
import json

def generate_backfill():
    # Read from .env
    env_path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\.env"
    supabase_url = ""
    supabase_key = ""
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                if "=" in line and not line.strip().startswith("#"):
                    k, v = line.strip().split("=", 1)
                    if k.strip() == "SUPABASE_URL":
                        supabase_url = v.strip()
                    elif k.strip() == "SUPABASE_SERVICE_KEY":
                        supabase_key = v.strip()

    html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>Tafseer.id - Semantic Embeddings Backfiller</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        body {{
            background-color: #131313;
            color: #E5E2E1;
            font-family: 'Outfit', sans-serif;
            margin: 0;
            padding: 40px;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            box-sizing: border-box;
        }}
        .card {{
            background-color: #1E1E1E;
            border: 1px solid #4E4639;
            border-radius: 24px;
            padding: 40px;
            width: 100%;
            max-width: 650px;
            box-shadow: 0 12px 40px rgba(0,0,0,0.5);
        }}
        h1 {{
            color: #E9C176;
            margin-top: 0;
            font-weight: 700;
            font-size: 28px;
            letter-spacing: -0.5px;
            display: flex;
            align-items: center;
            gap: 10px;
        }}
        p {{
            color: #9A8F80;
            line-height: 1.6;
            font-size: 15px;
        }}
        .status-container {{
            margin-top: 30px;
            background-color: #2A2A2A;
            border-radius: 16px;
            padding: 24px;
            border: 1px solid #4E4639;
        }}
        .progress-bar-bg {{
            background-color: #131313;
            height: 10px;
            border-radius: 5px;
            overflow: hidden;
            margin-top: 15px;
        }}
        .progress-bar-fill {{
            background: linear-gradient(90deg, #E9C176, #95D1D1);
            height: 100%;
            width: 0%;
            transition: width 0.3s ease;
        }}
        .stats {{
            display: flex;
            justify-content: space-between;
            margin-top: 15px;
            font-size: 13px;
            font-weight: 600;
        }}
        .stat-val {{
            color: #E9C176;
        }}
        .btn {{
            background: linear-gradient(135deg, #E9C176, #C5A059);
            color: #412D00;
            border: none;
            border-radius: 12px;
            padding: 14px 28px;
            font-size: 15px;
            font-weight: 700;
            cursor: pointer;
            width: 100%;
            margin-top: 24px;
            transition: transform 0.1s ease, opacity 0.2s ease;
        }}
        .btn:hover {{
            opacity: 0.95;
        }}
        .btn:active {{
            transform: scale(0.98);
        }}
        .btn:disabled {{
            background: #353534;
            color: #9A8F80;
            cursor: not-allowed;
        }}
        .log-box {{
            background-color: #131313;
            border-radius: 12px;
            height: 150px;
            overflow-y: auto;
            margin-top: 20px;
            padding: 12px;
            font-family: monospace;
            font-size: 11px;
            color: #95D1D1;
            border: 1px solid #4E4639;
        }}
        .input-group {{
            margin-bottom: 20px;
        }}
        .input-group label {{
            display: block;
            font-size: 12px;
            color: #9A8F80;
            margin-bottom: 6px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        .input-group input {{
            width: 100%;
            background-color: #2A2A2A;
            border: 1px solid #4E4639;
            color: #E5E2E1;
            padding: 12px;
            border-radius: 10px;
            box-sizing: border-box;
            font-size: 14px;
        }}
        .input-group input:focus {{
            border-color: #E9C176;
            outline: none;
        }}
    </style>
</head>
<body>
    <div class="card">
        <h1>✨ Semantic Embeddings Generator</h1>
        <p>This utility generates multilingual semantic embeddings (using the 384-dimensional <code>paraphrase-multilingual-MiniLM-L12-v2</code> model) for all translations in your Supabase database. This enables true concept-based search.</p>
        
        <div class="input-group">
            <label>Hugging Face API Token (Optional, paste to avoid rate limits)</label>
            <input type="password" id="hfToken" placeholder="hf_xxxxxxxxxxxxxxxxxxxxxxxx (optional)">
        </div>

        <div class="status-container">
            <div id="statusText" style="font-weight: 600;">Status: Ready</div>
            <div class="progress-bar-bg">
                <div class="progress-bar-fill" id="progressFill"></div>
            </div>
            <div class="stats">
                <div>Processed: <span id="processedCount" class="stat-val">0</span> / <span id="totalCount" class="stat-val">0</span></div>
                <div>Errors: <span id="errorCount" style="color: #ff6679;">0</span></div>
            </div>
        </div>

        <button class="btn" id="startBtn" onclick="startBackfill()">Start Generating Embeddings</button>
        
        <div class="log-box" id="logBox">
            [INFO] Ready to start. Make sure you have executed the migration script in Supabase SQL editor first!
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
    <script>
        const SUPABASE_URL = "{supabase_url}";
        const SUPABASE_KEY = "{supabase_key}";
        
        let supabaseClient;
        try {{
            supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
        }} catch (err) {{
            console.error(err);
        }}
        
        let running = false;
        let processed = 0;
        let total = 0;
        let errors = 0;

        function log(msg) {{
            const logBox = document.getElementById('logBox');
            logBox.innerHTML += `\\n[${{new Date().toLocaleTimeString()}}] ${{msg}}`;
            logBox.scrollTop = logBox.scrollHeight;
        }}

        async function startBackfill() {{
            if (running) return;
            running = true;
            document.getElementById('startBtn').disabled = true;
            document.getElementById('hfToken').disabled = true;
            
            log("Starting backfill check...");
            
            // 1. Fetch count of translations missing embeddings
            try {{
                const {{ count, error }} = await supabaseClient
                    .from('translations')
                    .select('id', {{ count: 'exact', head: true }})
                    .is('embedding', null);
                
                if (error) throw error;
                total = count || 0;
                document.getElementById('totalCount').innerText = total;
                log(`Found ${{total}} translations requiring embeddings.`);
                
                if (total === 0) {{
                    log("All translations already have embeddings!");
                    document.getElementById('statusText').innerText = "Status: Completed";
                    running = false;
                    return;
                }}
            }} catch (e) {{
                log(`Failed to fetch pending count: ${{e.message || e}}`);
                running = false;
                document.getElementById('startBtn').disabled = false;
                return;
            }}

            // 2. Fetch and process in batches of 50
            const batchSize = 50;
            processed = 0;
            
            while (processed < total && running) {{
                document.getElementById('statusText').innerText = `Status: Processing ${{processed}} / ${{total}}...`;
                
                // Fetch next batch of translations
                let batchData = [];
                try {{
                    const {{ data, error }} = await supabaseClient
                        .from('translations')
                        .select('id, text')
                        .is('embedding', null)
                        .limit(batchSize);
                    
                    if (error) throw error;
                    batchData = data || [];
                }} catch (e) {{
                    log(`Error fetching batch: ${{e.message || e}}`);
                    errors += batchSize;
                    document.getElementById('errorCount').innerText = errors;
                    await new Promise(r => setTimeout(r, 5000));
                    continue;
                }}

                if (batchData.length === 0) break;

                // Extract texts
                const texts = batchData.map(d => d.text);
                
                // Call Hugging Face API
                let embeddings = [];
                try {{
                    const hfToken = document.getElementById('hfToken').value.trim();
                    const headers = {{ "Content-Type": "application/json" }};
                    if (hfToken) {{
                        headers["Authorization"] = `Bearer ${{hfToken}}`;
                    }}
                    
                    const hfRes = await fetch("https://api-inference.huggingface.co/models/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2", {{
                        method: "POST",
                        headers: headers,
                        body: JSON.stringify({{ inputs: texts }})
                    }});
                    
                    if (hfRes.status === 503) {{
                        // Model loading, wait and retry
                        const info = await hfRes.json();
                        log(`Hugging Face model is loading: ${{info.estimated_time || 20}}s. Retrying...`);
                        await new Promise(r => setTimeout(r, (info.estimated_time || 20) * 1000));
                        continue;
                    }}
                    
                    if (!hfRes.ok) throw new Error(await hfRes.text());
                    embeddings = await hfRes.json();
                    
                    if (!Array.isArray(embeddings)) {{
                        throw new Error("Invalid response format from Hugging Face.");
                    }}
                }} catch (e) {{
                    log(`Hugging Face API error: ${{e.message || e}}`);
                    errors += batchData.length;
                    document.getElementById('errorCount').innerText = errors;
                    await new Promise(r => setTimeout(r, 5000));
                    continue;
                }}

                // Save embeddings back to Supabase
                try {{
                    const updates = batchData.map((d, idx) => {{
                        return {{
                            id: d.id,
                            embedding: embeddings[idx]
                        }};
                    }});
                    
                    const {{ error }} = await supabaseClient
                        .from('translations')
                        .upsert(updates);
                    
                    if (error) throw error;
                    
                    processed += batchData.length;
                    document.getElementById('processedCount').innerText = processed;
                    document.getElementById('progressFill').style.width = `${{(processed / total) * 100}}%`;
                    log(`Successfully generated and saved ${{batchData.length}} embeddings.`);
                }} catch (e) {{
                    log(`Supabase write error: ${{e.message || e}}`);
                    errors += batchData.length;
                    document.getElementById('errorCount').innerText = errors;
                    await new Promise(r => setTimeout(r, 5000));
                }}
                
                // Small delay to prevent rate limits
                await new Promise(r => setTimeout(r, 300));
            }}

            document.getElementById('statusText').innerText = "Status: Completed!";
            log("Backfill operation complete.");
            running = false;
        }}

        window.addEventListener('DOMContentLoaded', () => {{
            setTimeout(startBackfill, 1000);
        }});
    </script>
</body>
</html>
"""

    web_dir = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\web"
    if not os.path.exists(web_dir):
        os.makedirs(web_dir)
        
    backfill_path = os.path.join(web_dir, "backfill.html")
    with open(backfill_path, "w", encoding="utf-8") as f:
        f.write(html_content)
        
    print(f"Generated backfill.html at {backfill_path}")

if __name__ == "__main__":
    generate_backfill()
