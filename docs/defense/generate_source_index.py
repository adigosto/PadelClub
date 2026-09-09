"""Regenerate a read-only navigation index for the current working-tree source.

Run from any directory with Python 3. No dependencies or network access.
This is a lexical index, not an assertion that every declaration is reachable.
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SKIP = {'.git', '.vs', 'bin', 'obj', 'build', '.dart_tool', 'ephemeral', 'node_modules'}
ROOTS = ['PadelClub.Model', 'PadelClub.Services', 'PadelClub.WebAPI', 'PadelClub.WebAPI.Tests', 'UI', 'tools', 'scripts', '.github']
files = sorted(p for name in ROOTS for p in (ROOT / name).rglob('*')
               if p.is_file() and p.suffix in {'.cs', '.dart', '.csproj', '.yaml', '.yml', '.ps1'}
               and not set(p.relative_to(ROOT).parts) & SKIP)
records = []
for path in files:
    data = path.read_bytes()
    content = data.decode('utf-8-sig', errors='replace')
    lines = content.splitlines()
    relative = path.relative_to(ROOT).as_posix()
    declarations = [(n, line.strip()) for n, line in enumerate(lines, 1)
        if re.search(r'\b(class|interface|enum|record)\s+\w+|\b(public|protected|internal)\s+.*\(|\[.*(Http(Get|Post|Put|Delete|Patch)|Authorize|Route|AllowAnonymous)', line)
        and not line.strip().startswith('//')]
    records.append(dict(path=relative, lines=len(lines), sha256=hashlib.sha256(data).hexdigest(), declarations=declarations))
(OUT / 'source-index.json').write_text(json.dumps(records, indent=2), encoding='utf-8')

def link(path, line=None):
    return f"[{path}{':' + str(line) if line else ''}](../../{path})"

parts = ['# Working-tree source index', '',
    'Generated from the files on disk, including uncommitted changes. This lexical inventory supports navigation; it does not prove runtime reachability or passing tests.', '',
    f'Indexed {len(records)} source, test, build and script files. Generated build/cache directories are excluded. Migration files are included.', '',
    '## Controllers and declared actions', '',
    'Routes without a prefix inherit `[Route("[controller]")]` from BaseController. Inherited GET/GET-by-ID and CRUD actions still exist when they are not redeclared below. Check both class and method policies and ownership checks. This is not a replacement for generated Swagger.', '']
for record in records:
    path = record['path']
    if '/Controllers/' in path:
        parts.extend(['### ' + Path(path).stem, '', link(path), '', '```csharp'])
        parts.extend(f'{n}: {line}' for n, line in record['declarations'])
        parts.extend(['```', ''])
parts.extend(['## Database entities and mapping', ''])
for record in records:
    path = record['path']
    if '/Database/' not in path or '/Migrations/' in path or 'Context' in path:
        continue
    content = (ROOT / path).read_text(encoding='utf-8-sig')
    parts.extend(['### ' + Path(path).stem, '', link(path), '', '```csharp'])
    parts.extend(line.strip() for line in content.splitlines() if re.search(r'\bpublic\b', line) and not line.strip().startswith('//'))
    parts.extend(['```', ''])
parts.extend(['## EF relationships, keys and delete rules', '', link('PadelClub.Services/Database/PadelClubContext.cs'), '', '```csharp'])
context = (ROOT / 'PadelClub.Services/Database/PadelClubContext.cs').read_text(encoding='utf-8-sig')
parts.extend(f'{n}: {line.strip()}' for n, line in enumerate(context.splitlines(), 1)
             if re.search(r'modelBuilder.Entity|HasKey|HasOne|WithMany|WithOne|HasForeignKey|OnDelete|HasIndex|IsUnique|HasFilter|ToTable', line))
parts.extend(['```', '', '## UI files and feature groups', ''])
for record in records:
    path = record['path']
    if path.startswith('UI/') and '/lib/' in path and not path.endswith('.g.dart'):
        parts.append('- ' + link(path))
parts.extend(['', '## Complete indexed file manifest', '', 'Line counts describe file size, not review depth. SHA-256 fingerprints are retained in source-index.json.', ''])
parts.extend(f"- {link(r['path'])} ({r['lines']} lines)" for r in records)
(OUT / 'SOURCE_INDEX.md').write_text('\n'.join(parts) + '\n', encoding='utf-8')
print(json.dumps({'files': len(records), 'controllers': sum('/Controllers/' in r['path'] for r in records),
    'dbsets': len(re.findall(r'public DbSet<', context)), 'source_lines': sum(r['lines'] for r in records)}, indent=2))
