// Pinned Quint 0.33.1 uses RPC for TLA serialization. Use Apalache's file CLI
// instead, retaining Quint's parser, type/effect checks and convertInit.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = __dirname;
const versions = JSON.parse(fs.readFileSync(path.join(root, 'versions.json'), 'utf8'));
const quintRoot = path.join(root, 'node_modules/@informalsystems/quint');
if (JSON.parse(fs.readFileSync(path.join(quintRoot, 'package.json'), 'utf8')).version !== versions.quint) {
  throw Error('Quint version mismatch; run npm ci --prefix formal/quint --ignore-scripts');
}
const work = process.env.ROUTECLI_QUINT_OUTPUT;
if (!work || !path.isAbsolute(work)) throw Error('ROUTECLI_QUINT_OUTPUT must name an absolute output directory');
fs.mkdirSync(work, {recursive: true});
const {right, left} = require(path.join(root, 'node_modules/@sweet-monads/either'));
const dist = path.join(quintRoot, 'dist/src');
require(path.join(dist, 'compileToTlaplus')).compileToTlaplus = async (_endpoint, version, spec) => {
  if (version !== versions.apalache) return left({explanation: 'Apalache version mismatch', errors: []});
  const name = JSON.parse(spec).modules[0].name;
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(name)) return left({explanation: 'Unsupported TLA module name', errors: []});
  const input = path.join(work, 'input.qnt.json');
  const output = path.join(work, name + '.tla');
  fs.writeFileSync(input, spec);
  const cli = path.join(root, '.cache', `apalache-dist-${version}`, 'apalache/bin/apalache-mc');
  const result = spawnSync(cli, ['--out-dir=' + path.join(work, 'parse-logs'), 'parse', '--output=' + output, input],
    {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024});
  fs.writeFileSync(path.join(work, 'parse.log'), (result.stdout || '') + (result.stderr || ''));
  if (result.status !== 0 || !fs.existsSync(output)) return left({explanation: 'Apalache file conversion failed; see parse.log', errors: []});
  const tla = fs.readFileSync(output, 'utf8');
  // RPC additionally lifts LET arguments of fold operators. Refuse that case.
  if (/ApaFold\w*\(\s*LET/.test(tla)) return left({explanation: 'fold LET lifting is outside the supported file conversion path', errors: []});
  return right(tla);
};
require(path.join(dist, 'cli'));
