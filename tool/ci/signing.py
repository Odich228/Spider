"""Optional distribution signing. Private material lives only in runner temp."""
from contextlib import contextmanager
import base64
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def execute(args, *, capture=False, env=None):
    result = subprocess.run(args, capture_output=True, text=True, env=env)
    if result.returncode:
        raise RuntimeError(f'{Path(args[0]).name} signing operation failed (exit {result.returncode})')
    return result.stdout if capture else None


def sign_windows(bundle: Path):
    certificate = os.getenv('WINDOWS_CERTIFICATE_BASE64', '')
    if not certificate:
        return 'unsigned-portable'
    with tempfile.TemporaryDirectory(prefix='pautina-authenticode-', dir=os.getenv('RUNNER_TEMP')) as temp:
        pfx = Path(temp) / 'certificate.pfx'
        pfx.write_bytes(base64.b64decode(certificate, validate=True))
        env = dict(os.environ, PAUTINA_PFX=str(pfx))
        # Importing through the certificate store keeps passwords off the command line.
        script = r'''
$ErrorActionPreference='Stop'
$password=if([string]::IsNullOrEmpty($env:WINDOWS_CERTIFICATE_PASSWORD)){New-Object Security.SecureString}else{ConvertTo-SecureString $env:WINDOWS_CERTIFICATE_PASSWORD -AsPlainText -Force}
$pfx=Get-PfxData -FilePath $env:PAUTINA_PFX -Password $password
$thumb=$pfx.EndEntityCertificates[0].Thumbprint
if(Test-Path -LiteralPath "Cert:\CurrentUser\My\$thumb"){throw 'Certificate already installed'}
Import-PfxCertificate -FilePath $env:PAUTINA_PFX -Password $password -CertStoreLocation Cert:\CurrentUser\My | Out-Null
Write-Output $thumb
'''
        thumb = execute(['powershell.exe','-NoProfile','-Command',script], capture=True, env=env).strip()
        if not re.fullmatch('[A-Fa-f0-9]{40}', thumb):
            raise ValueError('Invalid Authenticode certificate thumbprint')
        try:
            kits = Path(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')) / 'Windows Kits/10/bin'
            tools = sorted(kits.glob('*/x64/signtool.exe'))
            if not tools: raise ValueError('Windows SDK signtool is missing')
            executable = bundle / 'pautina.exe'
            execute([str(tools[-1]), 'sign', '/sha1', thumb, '/fd', 'SHA256', '/tr', 'http://timestamp.digicert.com', '/td', 'SHA256', str(executable)])
            execute([str(tools[-1]), 'verify', '/pa', '/all', str(executable)])
            return 'authenticode-timestamped'
        finally:
            execute(['powershell.exe','-NoProfile','-Command',f'Remove-Item -LiteralPath Cert:\\CurrentUser\\My\\{thumb} -Force'])


@contextmanager
def mac_keychain():
    certificate = os.getenv('MACOS_CERTIFICATE_BASE64','')
    if not certificate:
        yield None
        return
    import secrets, shlex
    with tempfile.TemporaryDirectory(prefix='pautina-developer-id-',dir=os.getenv('RUNNER_TEMP')) as temp:
        cert = Path(temp) / 'developer-id.p12'
        cert.write_bytes(base64.b64decode(certificate, validate=True))
        keychain = Path(temp) / 'signing.keychain-db'
        password = secrets.token_urlsafe(32)
        previous = shlex.split(execute(['security','list-keychains','-d','user'],capture=True))
        try:
            execute(['security','create-keychain','-p',password,str(keychain)])
            execute(['security','set-keychain-settings','-lut','21600',str(keychain)])
            execute(['security','unlock-keychain','-p',password,str(keychain)])
            execute(['security','import',str(cert),'-P',os.getenv('MACOS_CERTIFICATE_PASSWORD',''),'-t','cert','-f','pkcs12','-k',str(keychain),'-T','/usr/bin/codesign'])
            execute(['security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-k',password,str(keychain)])
            execute(['security','list-keychains','-d','user','-s',str(keychain),*previous])
            identities=execute(['security','find-identity','-v','-p','codesigning',str(keychain)],capture=True)
            found=re.findall(r'([A-Fa-f0-9]{40}) "Developer ID Application:',identities)
            if len(found)!=1: raise ValueError('Expected one Developer ID Application identity')
            yield found[0]
        finally:
            execute(['security','list-keychains','-d','user','-s',*previous])
            if keychain.exists(): execute(['security','delete-keychain',str(keychain)])


def package_macos(app: Path, target: Path, root: Path):
    notary = [os.getenv(name,'') for name in ['MACOS_NOTARY_KEY_BASE64','MACOS_NOTARY_KEY_ID','MACOS_NOTARY_ISSUER_ID']]
    if any(notary) and not all(notary): raise ValueError('Configure all three MACOS_NOTARY_* secrets')
    with mac_keychain() as identity:
        if all(notary) and identity is None: raise ValueError('Notarization requires Developer ID signing')
        if identity:
            # Sign nested Mach-O binaries first, then framework bundles and the app.
            for file in sorted(app.rglob('*'), key=lambda path: len(path.parts), reverse=True):
                if file.is_file() and not file.is_symlink():
                    with file.open('rb') as stream: magic=stream.read(4)
                    if magic in {b'\xcf\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'}:
                        execute(['codesign','--force','--options','runtime','--timestamp','--sign',identity,str(file)])
                if file.is_dir() and file.suffix in {'.framework','.app'}:
                    execute(['codesign','--force','--options','runtime','--timestamp','--sign',identity,str(file)])
            execute(['codesign','--force','--options','runtime','--timestamp','--sign',identity,'--entitlements',str(root/'macos/Runner/Release.entitlements'),str(app)])
            execute(['codesign','--verify','--deep','--strict',str(app)])
        execute(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(target)])
        if all(notary):
            with tempfile.TemporaryDirectory(prefix='pautina-notary-',dir=os.getenv('RUNNER_TEMP')) as temp:
                key=Path(temp)/'AuthKey.p8';key.write_bytes(base64.b64decode(notary[0],validate=True))
                result=json.loads(execute(['xcrun','notarytool','submit',str(target),'--key',str(key),'--key-id',notary[1],'--issuer',notary[2],'--wait','--output-format','json'],capture=True))
                if result.get('status')!='Accepted': raise ValueError('Apple notarization was not accepted')
            execute(['xcrun','stapler','staple',str(app)])
            target.unlink()
            execute(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(app),str(target)])
            return 'developer-id-notarized'
        return 'developer-id-not-notarized' if identity else 'ad-hoc-not-notarized'
