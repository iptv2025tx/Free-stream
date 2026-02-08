import zipfile
import os

basedir = os.path.dirname(os.path.abspath(__file__))
zippath = os.path.join(basedir, 'iptv-roku.zip')

if os.path.exists(zippath):
    os.remove(zippath)

with zipfile.ZipFile(zippath, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(basedir):
        for f in files:
            if f.endswith(('.zip', '.py')):
                continue
            filepath = os.path.join(root, f)
            arcname = os.path.relpath(filepath, basedir).replace(os.sep, '/')
            zf.write(filepath, arcname)
            print(f'  + {arcname}')

print(f'ZIP criado: {zippath}')
