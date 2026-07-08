f = open('lib/features/home/home_screen.dart', encoding='utf-8')
content = f.read()
f.close()

# ── 1. Replace the SizedBox(height:16) after onSubmitted with our Advanced Search block ──
old_after_field = (
    'onSubmitted: (_) => _doSearch(),\n'
    '                            textInputAction: TextInputAction.search,\n'
    '                          ),\n'
    '                          const SizedBox(height: 16),'
)

new_after_field = (
    'onSubmitted: (_) => _doSearch(),\n'
    '                            textInputAction: TextInputAction.search,\n'
    '                          ),\n'
    '                          const SizedBox(height: 6),\n'
    '                          // Advanced Search toggle row\n'
    '                          Row(\n'
    '                            mainAxisAlignment: MainAxisAlignment.spaceBetween,\n'
    '                            children: [\n'
    '                              TextButton.icon(\n'
    '                                icon: Icon(\n'
    '                                  _showAdvanced ? Icons.tune : Icons.tune_outlined,\n'
    '                                  size: 16,\n'
    '                                  color: AppTheme.primary,\n'
    '                                ),\n'
    '                                label: Text(\n'
    '                                  isEn ? \'Advanced Search\' : \'Pencarian Lanjutan\',\n'
    '                                  style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),\n'
    '                                ),\n'
    '                                onPressed: () => setState(() => _showAdvanced = !_showAdvanced),\n'
    '                              ),\n'
    '                              if (_searchController.text.trim().isNotEmpty)\n'
    '                                TextButton(\n'
    '                                  onPressed: _doSearch,\n'
    '                                  child: Text(\n'
    '                                    isEn ? \'SEARCH\' : \'CARI\',\n'
    '                                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),\n'
    '                                  ),\n'
    '                                ),\n'
    '                            ],\n'
    '                          ),\n'
    '                          // Advanced Search panel (hidden by default)\n'
    '                          AnimatedSize(\n'
    '                            duration: const Duration(milliseconds: 250),\n'
    '                            curve: Curves.easeInOut,\n'
    '                            child: _showAdvanced\n'
    '                                ? Padding(\n'
    '                                    padding: const EdgeInsets.only(top: 8),\n'
    '                                    child: Container(\n'
    '                                      padding: const EdgeInsets.all(14),\n'
    '                                      decoration: BoxDecoration(\n'
    '                                        color: AppTheme.surfaceContainerHigh,\n'
    '                                        borderRadius: BorderRadius.circular(16),\n'
    '                                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),\n'
    '                                      ),\n'
    '                                      child: Column(\n'
    '                                        crossAxisAlignment: CrossAxisAlignment.stretch,\n'
    '                                        children: [\n'
    '                                          // Semantic toggle\n'
    '                                          Row(\n'
    '                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,\n'
    '                                            children: [\n'
    '                                              Row(children: [\n'
    '                                                Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 16),\n'
    '                                                const SizedBox(width: 8),\n'
    '                                                Text(\n'
    '                                                  isEn ? \'Semantic (AI)\' : \'Semantik (AI)\',\n'
    '                                                  style: TextStyle(color: AppTheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),\n'
    '                                                ),\n'
    '                                              ]),\n'
    '                                              Switch(\n'
    '                                                value: _semanticSearch,\n'
    '                                                activeColor: AppTheme.primary,\n'
    '                                                onChanged: (v) => setState(() => _semanticSearch = v),\n'
    '                                              ),\n'
    '                                            ],\n'
    '                                          ),\n'
    '                                          if (!_semanticSearch) ...[\n'
    '                                            const Divider(height: 20),\n'
    '                                            Text(\n'
    '                                              isEn ? \'SEARCH IN:\' : \'CARI DI DALAM:\',\n'
    '                                              style: TextStyle(color: AppTheme.outline, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),\n'
    '                                            ),\n'
    '                                            const SizedBox(height: 10),\n'
    '                                            Wrap(spacing: 12, runSpacing: 8, children: [\n'
    '                                              _buildAdvancedCheckbox(label: isEn ? \'Arabic Text\' : \'Teks Arab\', value: _searchQuran, onChanged: (v) => setState(() => _searchQuran = v ?? true)),\n'
    '                                              _buildAdvancedCheckbox(label: isEn ? \'Translation\' : \'Terjemahan\', value: _searchTranslation, onChanged: (v) => setState(() => _searchTranslation = v ?? true)),\n'
    '                                              _buildAdvancedCheckbox(label: \'Tafsir\', value: _searchTafsir, onChanged: (v) => setState(() => _searchTafsir = v ?? true)),\n'
    '                                              _buildAdvancedCheckbox(label: \'Asbabun Nuzul\', value: _searchNuzul, onChanged: (v) => setState(() => _searchNuzul = v ?? true)),\n'
    '                                              _buildAdvancedCheckbox(label: isEn ? \'Topics / Tags\' : \'Topik / Tag\', value: _searchTag, onChanged: (v) => setState(() => _searchTag = v ?? true)),\n'
    '                                            ]),\n'
    '                                          ],\n'
    '                                        ],\n'
    '                                      ),\n'
    '                                    ),\n'
    '                                  )\n'
    '                                : const SizedBox.shrink(),\n'
    '                          ),\n'
    '                          const SizedBox(height: 16),'
)

if old_after_field in content:
    content = content.replace(old_after_field, new_after_field, 1)
    print('Search field block: REPLACED')
else:
    print('ERROR: search field pattern not found')

# ── 2. Add _buildAdvancedCheckbox helper before _buildQuickGrid ──
old_quick_grid = '  Widget _buildQuickGrid(bool isEn) {'
new_quick_grid = '''  Widget _buildAdvancedCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: AppTheme.onSurface, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickGrid(bool isEn) {'''

if old_quick_grid in content:
    content = content.replace(old_quick_grid, new_quick_grid, 1)
    print('_buildAdvancedCheckbox helper: ADDED')
else:
    print('ERROR: _buildQuickGrid anchor not found')

with open('lib/features/home/home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done. File size:', len(content))
