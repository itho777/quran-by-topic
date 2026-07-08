with open(r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "bottom:" in line:
        print(f"Line {i+1}: {line.strip()}")
        # print 3 lines before and after
        start = max(0, i - 3)
        end = min(len(lines), i + 4)
        for j in range(start, end):
            print(f"  {j+1}: {lines[j].rstrip()}")
        print("-" * 40)
