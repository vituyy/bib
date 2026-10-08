"""Checks that no script has more than 200 local variables alive at once (Roblox refuses to run such a script:
"Out of local registers"; the whole HUD disappears if it is Main.client).

Usage: python3 tools/check_locals.py /path/to/luau-ast        (luau-ast comes with the Luau releases on GitHub)
Exit code 1 when a script is over the limit. Main.client.luau sits at exactly 200: put new code in another script.
"""
import json, os, subprocess, sys
sys.setrecursionlimit(100000)
LIMIT = 200
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


results = []


class Ctx:
    def __init__(self, name, loc): self.n = 0; self.max = 0; self.name = name; self.loc = loc
    def push(self, k=1):
        self.n += k; self.max = max(self.max, self.n)
def walk(node, ctx):
    if isinstance(node, list):
        for x in node: walk(x, ctx)
        return
    if not isinstance(node, dict): return
    t = node.get('type')
    if t == 'AstExprFunction':
        c = Ctx('function', node.get('location'))
        c.push(len(node.get('args', [])) + (1 if node.get('self') else 0))
        walk(node['body'], c)
        results.append(c)
        return
    if t == 'AstStatBlock':
        save = ctx.n
        for s in node['body']: walk(s, ctx)
        ctx.n = save
        return
    if t == 'AstStatLocal':
        walk(node.get('values', []), ctx); ctx.push(len(node['vars'])); return
    if t == 'AstStatLocalFunction':
        ctx.push(1); walk(node['func'], ctx); return
    if t == 'AstStatFor':
        save = ctx.n
        for k in ('from', 'to', 'step'):
            if node.get(k): walk(node[k], ctx)
        ctx.push(1); walk(node['body'], ctx); ctx.n = save; return
    if t == 'AstStatForIn':
        save = ctx.n
        walk(node.get('values', []), ctx); ctx.push(len(node['vars'])); walk(node['body'], ctx); ctx.n = save; return
    if t == 'AstStatRepeat':
        save = ctx.n
        # body block statements stay in scope for the condition
        for s in node['body']['body']: walk(s, ctx)
        walk(node['condition'], ctx); ctx.n = save; return
    for k, v in node.items():
        if isinstance(v, (dict, list)): walk(v, ctx)


def check(ast_path, file):
    ast = json.loads(subprocess.run([ast_path, file], capture_output=True, text=True, check=True).stdout)
    results.clear()
    root = Ctx('main chunk', '0')
    walk(ast['root'], root)
    results.append(root)
    return max(c.max for c in results)


bad = False
for folder, _, files in os.walk(os.path.join(ROOT, 'src')):
    for name in sorted(files):
        if name.endswith('.luau'):
            path = os.path.join(folder, name)
            most = check(sys.argv[1], path)
            if most >= LIMIT - 10:
                print(('OVER THE LIMIT  ' if most > LIMIT else 'close to limit  ') + '%3d locals  %s' % (most, os.path.relpath(path, ROOT)))
            bad = bad or most > LIMIT
sys.exit(1 if bad else 0)
