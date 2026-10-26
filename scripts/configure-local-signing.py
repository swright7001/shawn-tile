#!/usr/bin/env python3
"""Bind this user's local builds to one existing Keychain signing certificate."""
import json, os, pathlib, re, subprocess, sys

label = sys.argv[1] if len(sys.argv) > 1 else 'Shawn Tile Local Development'
root = pathlib.Path.home() / 'Library/Application Support/Shawn Tile/Signing'
config = root / 'identity.json'
if config.exists():
    current = json.loads(config.read_text())
    print('Local signing is already configured: ' + current['identity'])
    print('The existing identity will be reused. No certificate was replaced.')
    sys.exit(0)
result = subprocess.run(['/usr/bin/security','find-certificate','-a','-c',label,'-Z'],capture_output=True,text=True)
identities = list(dict.fromkeys(re.findall(r'SHA-1 hash: ([0-9A-Fa-f]{40})',result.stdout)))
if len(identities) != 1:
    sys.exit('Expected one Keychain certificate named "'+label+'". Create a Self Signed Root / Code Signing certificate in Keychain Access first. No settings changed.')
identity = identities[0].upper()
listing = subprocess.run(['/usr/bin/security','find-identity','-p','codesigning'],capture_output=True,text=True,check=True).stdout
if identity not in listing.upper():
    sys.exit('The certificate does not have an available code-signing private key. No settings changed.')
root.mkdir(parents=True,exist_ok=True,mode=0o700)
os.chmod(root,0o700)
fd = os.open(config,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
with os.fdopen(fd,'w') as handle:
    json.dump({'identity':identity,'label':label,'bundle_identifier':'com.shawnwright.ShawnTile'},handle,indent=2)
    handle.write('\n')
print('Configured local signing: '+identity)
print('Private key remains in Keychain. No certificate trust settings were changed.')
