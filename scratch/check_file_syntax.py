import os

path = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\ayah_detail\ayah_detail_screen.dart"

with open(path, 'rb') as f:
    raw = f.read()

print("File size:", len(raw))

# Check for null bytes or weird binary characters
null_bytes = raw.count(b'\x00')
print("Null bytes:", null_bytes)

try:
    text = raw.decode('utf-8')
    print("Decoded as utf-8 successfully")
except UnicodeDecodeError as e:
    print("utf-8 decode error:", e)
    try:
        text = raw.decode('latin-1')
        print("Decoded as latin-1 successfully")
    except Exception as e2:
        print("latin-1 decode error:", e2)

# Check braces matching
open_curly = text.count('{')
close_curly = text.count('}')
open_paren = text.count('(')
close_paren = text.count(')')
open_square = text.count('[')
close_square = text.count(']')

print(f"Braces: {{ = {open_curly}, }} = {close_curly}")
print(f"Parentheses: ( = {open_paren}, ) = {close_paren}")
print(f"Square brackets: [ = {open_square}, ] = {close_square}")
