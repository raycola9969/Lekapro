from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
for file in (root/'Lekapro').glob('*.swift'):
    text=file.read_text(encoding='utf-8')
    updated=re.sub(r'\bButton\(("[^"\n]*"), systemImage:',r'ActionButton(\1, systemImage:',text)
    updated=updated.replace('ContentUnavailableView(', 'EmptyStateView(')
    updated=updated.replace('.topBarTrailing', '.navigationBarTrailing')
    updated=updated.replace('{ _, phase in', '{ phase in').replace('{ _, url in', '{ url in')
    if updated!=text: file.write_text(updated,encoding='utf-8')
