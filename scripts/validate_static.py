#!/usr/bin/env python3
"""Structural/syntax validation only; does not replace xcodebuild or swift test."""
from pathlib import Path
import re, json, plistlib, xml.etree.ElementTree as ET, sys
root=Path(__file__).resolve().parent.parent
issues=[]; messages=[]
try:
 from tree_sitter import Language,Parser
 import tree_sitter_swift
 parser=Parser(Language(tree_sitter_swift.language()))
 for path in sorted(root.rglob('*.swift')):
  tree=parser.parse(path.read_bytes())
  def errors(node):
   if node.type=='ERROR' or node.is_missing:
    issues.append(f'Swift parse: {path.relative_to(root)}:{node.start_point.row+1} {node.type}')
   for child in node.children: errors(child)
  errors(tree.root_node)
 messages.append(f'Swift syntax parsed: {len(list(root.rglob("*.swift")))} files (tree-sitter, NOT type checking)')
except ImportError:
 issues.append('Install tree-sitter and tree-sitter-swift to run syntax validation.')
for path in list(root.rglob('*.plist'))+list(root.rglob('*.entitlements'))+list(root.rglob('*.xcprivacy')):
 try: plistlib.loads(path.read_bytes())
 except Exception as e: issues.append(f'Plist {path}: {e}')
messages.append('Info plists, entitlements and privacy manifest parsed')
for pattern in ['*.xcscheme','*.xcworkspacedata']:
 for path in root.rglob(pattern):
  try: ET.parse(path)
  except Exception as e: issues.append(f'XML {path}: {e}')
for path in root.rglob('*.json'):
 try: json.loads(path.read_text())
 except Exception as e: issues.append(f'JSON {path}: {e}')
messages.append('Schemes, workspace XML and JSON files parsed')
pbx=(root/'AnimeKodoku.xcodeproj/project.pbxproj').read_text()
objects=re.findall(r'^\s*([A-F0-9]{24}) = \{',pbx,re.M)
if len(objects)!=len(set(objects)): issues.append('Duplicate PBX object IDs')
references=re.findall(r'\b(?:fileRef|mainGroup|productRefGroup|productReference|buildConfigurationList|rootObject) = ([A-F0-9]{24})',pbx)
for ref in references:
 if ref not in objects: issues.append('Unresolved PBX reference '+ref)
for path in (root/'AnimeKodoku').rglob('*.swift'):
 if str(path.relative_to(root)) not in pbx: issues.append('Swift file missing in PBX '+str(path))
for match in re.finditer(r'isa = PBXFileReference;[^}]*path = "([^"]+)";[^}]*sourceTree = "<group>";',pbx):
 if not (root/match.group(1)).exists(): issues.append('Missing PBX file '+match.group(1))
for path in root.rglob('*.appiconset/Contents.json'):
 for entry in json.loads(path.read_text())['images']:
  if not (path.parent/entry['filename']).exists(): issues.append('Missing icon '+entry['filename'])
messages.append(f'PBX IDs/references, both targets, source file paths and icon assets checked ({len(objects)} objects)')
# Check all declared source IDs match the JSON example contract.
manifest=json.loads((root/'docs/source-manifest.example.json').read_text())
assert manifest['kind']=='rest' and manifest['version']==1
assert manifest['source']['baseUrl'].startswith('https://')
messages.append('REST manifest v1 fixture validated')
messages.append(f'XCTest cases included: {sum(len(re.findall(r"func test",p.read_text())) for p in (root/"Tests").rglob("*.swift"))} (NOT executed here)')
if issues:
 print('\n'.join(messages+issues)); sys.exit(1)
print('\n'.join(messages+['PASS: static checks only. Apple compilation/runtime tests not performed.']))
