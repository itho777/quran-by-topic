import os

search_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\search\search_screen.dart"
home_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\home\home_screen.dart"
profile_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\profile\profile_screen.dart"
more_file = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\lib\features\more\more_screen.dart"

# ─── 1. Fix Search Screen (Double Button) ───
with open(search_file, 'r', encoding='utf-8') as f:
    search_content = f.read()

# Replace the double IconButton block
old_buttons = """            IconButton(
              icon: Icon(
                _showAdvancedOptions ? Icons.tune : Icons.tune_outlined,
                color: _showAdvancedOptions ? AppTheme.primary : AppTheme.outline,
              ),
              tooltip: 'Advanced Search Options',
              onPressed: () {
                setState(() {
                  _showAdvancedOptions = !_showAdvancedOptions;
                });
              },
            ),
            IconButton(
              icon: Icon(
                _showAdvancedOptions ? Icons.tune : Icons.tune_outlined,
                color: _showAdvancedOptions ? AppTheme.primary : AppTheme.outline,
              ),
              tooltip: 'Advanced Search Options',
              onPressed: () {
                setState(() {
                  _showAdvancedOptions = !_showAdvancedOptions;
                });
              },
            ),"""

new_button = """            IconButton(
              icon: Icon(
                _showAdvancedOptions ? Icons.tune : Icons.tune_outlined,
                color: _showAdvancedOptions ? AppTheme.primary : AppTheme.outline,
              ),
              tooltip: 'Advanced Search Options',
              onPressed: () {
                setState(() {
                  _showAdvancedOptions = !_showAdvancedOptions;
                });
              },
            ),"""

search_content_normalised = search_content.replace('\r\n', '\n')
old_buttons_normalised = old_buttons.replace('\r\n', '\n')
new_button_normalised = new_button.replace('\r\n', '\n')

if old_buttons_normalised in search_content_normalised:
    search_content_normalised = search_content_normalised.replace(old_buttons_normalised, new_button_normalised, 1)
    print("search_screen.dart duplicate button: FIXED")
else:
    print("WARNING: duplicate buttons pattern not found in search_screen.dart!")

if '\r\n' in search_content:
    search_content_normalised = search_content_normalised.replace('\n', '\r\n')

with open(search_file, 'w', encoding='utf-8') as f:
    f.write(search_content_normalised)


# ─── 2. Fix Home Screen (go -> push) ───
with open(home_file, 'r', encoding='utf-8') as f:
    home_content = f.read()

old_home_go = "onPressed: () => context.go('/settings'),"
new_home_push = "onPressed: () => context.push('/settings'),"

home_content_normalised = home_content.replace('\r\n', '\n')
if old_home_go in home_content_normalised:
    home_content_normalised = home_content_normalised.replace(old_home_go, new_home_push, 1)
    print("home_screen.dart go -> push: FIXED")
else:
    print("WARNING: home_screen.dart settings button not found!")

if '\r\n' in home_content:
    home_content_normalised = home_content_normalised.replace('\n', '\r\n')

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(home_content_normalised)


# ─── 3. Fix Profile Screen (go -> push) ───
with open(profile_file, 'r', encoding='utf-8') as f:
    profile_content = f.read()

old_profile_go1 = "onTap: () => context.go('/settings'),"
new_profile_push1 = "onTap: () => context.push('/settings'),"
old_profile_go2 = "onPressed: () => context.go('/settings'),"
new_profile_push2 = "onPressed: () => context.push('/settings'),"

profile_content_normalised = profile_content.replace('\r\n', '\n')

if old_profile_go1 in profile_content_normalised:
    profile_content_normalised = profile_content_normalised.replace(old_profile_go1, new_profile_push1)
    print("profile_screen.dart go -> push (tile): FIXED")
if old_profile_go2 in profile_content_normalised:
    profile_content_normalised = profile_content_normalised.replace(old_profile_go2, new_profile_push2)
    print("profile_screen.dart go -> push (button): FIXED")

if '\r\n' in profile_content:
    profile_content_normalised = profile_content_normalised.replace('\n', '\r\n')

with open(profile_file, 'w', encoding='utf-8') as f:
    f.write(profile_content_normalised)


# ─── 4. Fix More Screen AppBar back button ───
with open(more_file, 'r', encoding='utf-8') as f:
    more_content = f.read()

old_more_leading = """        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppTheme.primary),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,"""

# Double newlines formatting in more_screen.dart might exist. Let's make it robust:
new_more_leading = """        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primary),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),"""

more_content_normalised = more_content.replace('\r\n', '\n')
old_more_leading_normalised = old_more_leading.replace('\r\n', '\n')

# Check if double newline exists
if old_more_leading_normalised in more_content_normalised:
    more_content_normalised = more_content_normalised.replace(old_more_leading_normalised, new_more_leading)
    print("more_screen.dart back button: FIXED")
else:
    # Try with double newlines
    old_more_leading_double = """        leading: Navigator.canPop(context)

            ? IconButton(

                icon: Icon(Icons.arrow_back, color: AppTheme.primary),

                tooltip: 'Back',

                onPressed: () => Navigator.of(context).pop(),

              )

            : null,"""
    old_more_leading_double_normalised = old_more_leading_double.replace('\r\n', '\n')
    if old_more_leading_double_normalised in more_content_normalised:
        more_content_normalised = more_content_normalised.replace(old_more_leading_double_normalised, new_more_leading)
        print("more_screen.dart back button (double newlines): FIXED")
    else:
        print("WARNING: more_screen.dart back button pattern not found!")

if '\r\n' in more_content:
    more_content_normalised = more_content_normalised.replace('\n', '\r\n')

with open(more_file, 'w', encoding='utf-8') as f:
    f.write(more_content_normalised)

print("Done patching.")
