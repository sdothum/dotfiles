import hashlib,json,os,pathlib,stat
ROOT=pathlib.Path('/home/shum/stow/zephyr/experiments/nim-cirrus/stage6/stage7d3c4b91')
pins={
'Planning-33':('host-probe-model-a-offline-implementation-planning-33','planning_manifest.json','0fe12cbc07d9c2bb49f5864b4d7ab0b827b3c591ee312af8e48d5e6b2c84259d'),
'Certification-71':('host-probe-model-a-m4-independent-catalog-certification-71','certification_manifest.json','fcf83e9219974104bb2439363a1f94ae01d2f171effb289aab3c5263fa168996'),
'Correction-70':('host-probe-model-a-m4-catalog-commitment-correction-70','correction_manifest.json','013431c96dadca2b51b11060849032f2d776c18f82635139a376bd2cb3130aa4'),
'Certification-69':('host-probe-model-a-m4-independent-correction-certification-69','certification_manifest.json','2df9d6af8defd47f739bec421fc5e7956acd9861a91e913b1ae2f35e362ef3c2'),
'Bootstrap-68':('host-probe-model-a-m4-containment-bootstrap-68','bootstrap_manifest.json','6b123b37f49af5b496d96cea5ebc9a80083fc3019210584a9bcb888622c02a1f'),
'Certification-62':('host-probe-model-a-m3-independent-correction-certification-62','certification_manifest.json','27797d6550478b9ab131a85fd4d7dbd4517ae9585ad709ba0219aa79c1ea0d9e'),
'Certification-57':('host-probe-model-a-m2-contained-snapshot-certification-57','certification_manifest.json','0fc9fe8dd2b00c6d7da2109921cf629d006ccaef3aa6e886625de4a5d19baf7a'),
'Review-50':('host-probe-model-a-m2-store-authority-review-50','review_manifest.json','62352c747ee89e06f99d84bdc51e09ae2a739d76e7648344db897d375ae85724')}
results=[]
for name,(dirname,mf,expected) in pins.items():
 p=ROOT/dirname; manifest_path=p/mf
 if not manifest_path.is_file(): raise SystemExit(f'missing {name} manifest')
 actual=hashlib.sha256(manifest_path.read_bytes()).hexdigest(); doc=json.loads(manifest_path.read_text()); entries=doc.get('entries',[]); errors=[]; types={}
 if actual!=expected: errors.append('manifest pin mismatch')
 for e in entries:
  rel=e.get('path'); q=p/rel; typ=e.get('type'); types[typ]=types.get(typ,0)+1
  if not q.exists() and not q.is_symlink(): errors.append('missing:'+str(rel)); continue
  st=q.lstat()
  if typ in ('file','regular'):
   if not stat.S_ISREG(st.st_mode): errors.append('type:'+str(rel))
   elif hashlib.sha256(q.read_bytes()).hexdigest()!=e.get('sha256'): errors.append('hash:'+str(rel))
   elif e.get('size') is not None and st.st_size!=e['size']: errors.append('size:'+str(rel))
  elif typ=='directory' and not stat.S_ISDIR(st.st_mode): errors.append('type:'+str(rel))
 actual_paths=[]
 for base,dirs,files in os.walk(p,followlinks=False):
  for d in dirs: actual_paths.append((pathlib.Path(base)/d).relative_to(p).as_posix())
  for f in files:
   q=pathlib.Path(base)/f
   if q!=manifest_path: actual_paths.append(q.relative_to(p).as_posix())
 covered={e.get('path') for e in entries}; unrecorded=sorted(set(actual_paths)-covered); missing=sorted(covered-set(actual_paths))
 file_only=not any(e.get('type')=='directory' for e in entries)
 results.append({'package':name,'directory':dirname,'manifest_file':mf,'pinned_sha256':expected,'actual_sha256':actual,'manifest_hash_match':actual==expected,'entry_count':len(entries),'types':types,'errors':errors,'unrecorded_entries':unrecorded,'missing_entries':missing,'file_only_manifest':file_only,'complete_available_inventory':not errors and not unrecorded and not missing,'directory_metadata_limit':'manifest omits directory entries/metadata' if file_only else None})
print(json.dumps(results,indent=2,sort_keys=True))
