with open(r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

# Let's search back from line 2396 to see what widget contains all these buttons.
# We will count brace levels to find the open parenthesis/brace.
brace_count = 0
for idx in range(2395, 2000, -1):
    line = lines[idx]
    if "AnimatedPositioned" in line or "Positioned" in line or "Container" in line:
        print(f"Line {idx+1}: {line.strip()}")
