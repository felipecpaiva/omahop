import json,sys
for l in open(sys.argv[1]):
    if l.startswith('{'):
        d=json.loads(l);i=d.get('img',{})
        print(d['name'],d.get('ms'),i.get('corner'),(i.get('top') or [''])[0],d.get('match'),d.get('expectBefore'),d.get('expectAfter'),(d.get('error') or str(d.get('raw')) or '')[:110].replace('\n',' '))
    else: print(l[:330].rstrip())
