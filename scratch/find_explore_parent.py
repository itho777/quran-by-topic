with open(r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\mushaf\mushaf_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Let's search for "explore_outlined" and check its surrounding lines in a larger block
idx = text.find("explore_outlined")
if idx != -1:
    start_idx = max(0, idx - 4000)
    end_idx = min(len(text), idx + 2000)
    snippet = text[start_idx:end_idx]
    # Find all occurrences of Positioned/AnimatedPositioned in this snippet
    print("Found explore_outlined. Printing surrounding structures:")
    # Let's count line numbers
    lines = text.splitlines()
    target_line = 0
    for i, line in enumerate(lines):
        if "explore_outlined" in line:
            target_line = i
            break
    print(f"Target line is {target_line+1}")
    # Print lines from target_line - 150 to target_line + 50
    for j in range(max(0, target_line - 150), min(len(lines), target_line + 50)):
        print(f"{j+1}: {lines[j]}")
