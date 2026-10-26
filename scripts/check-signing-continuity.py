#!/usr/bin/env python3
"""Verify different app versions have the same signer-bound update identity."""
import pathlib,re,subprocess,sys
if len(sys.argv) != 3:
    sys.exit('Usage: check-signing-continuity.py old.app new.app')
apps = [pathlib.Path(p) for p in sys.argv[1:]]
def requirement(app):
    subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(app)],check=True)
    result = subprocess.run(['/usr/bin/codesign','-d','-r-',str(app)],capture_output=True,text=True,check=True)
    output = result.stdout+'\n'+result.stderr
    match = re.search(r'(?m)^#?\s*designated =>(.+)$',output)
    if not match:
        sys.exit('FAIL: no designated requirement was returned.')
    value = match.group(1).strip()
    if not re.fullmatch(r'identifier "com\.shawnwright\.ShawnTile" and certificate (?:leaf|0) = H"[0-9a-fA-F]{40}"',value):
        sys.exit('FAIL: requirement must pin both Shawn Tile and its signing certificate.')
    return value
old,new = map(requirement,apps)
if old != new:
    sys.exit('FAIL: designated requirement changed. A permission refresh may be needed.')
for app in apps:
    subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict','--test-requirement','='+old,str(app)],check=True)
print('PASS: both versions satisfy the same certificate-pinned designated requirement')
print(old)
