// Roda um Code node do bot fora do n8n, com $, $input e https falsos: cada
// chamada HTTP fica gravada e a resposta vem da tabela de rotas do teste.
//   node ops/n8n/test/catalogo.test.js
const fs = require('fs');
const Module = require('module');
const { EventEmitter } = require('events');
const calls = [];
let routes = {};
const fakeHttps = {
  request(url, opts, cb) {
    const req = new EventEmitter();
    req.setTimeout = () => {}; req.destroy = () => {};
    req.end = data => {
      calls.push({ method: opts.method, url, body: data ? JSON.parse(data) : null });
      const key = Object.keys(routes).find(k => url.includes(k));
      const [status, body] = key ? routes[key] : [200, {}];
      const res = new EventEmitter(); res.statusCode = status;
      cb(res); res.emit('data', JSON.stringify(body)); res.emit('end');
    };
    return req;
  },
  get(url, opts, cb) { const r = fakeHttps.request(url, Object.assign({ method: 'GET' }, opts), cb); r.end(); return r; },
};
const orig = Module._load;
Module._load = function (req, ...rest) { return req === 'https' ? fakeHttps : orig.call(this, req, ...rest); };
module.exports = async function run(file, nodes, input, r) {
  routes = r || {}; calls.length = 0;
  const $ = name => ({ first: () => ({ json: nodes[name] }) });
  const $input = { first: () => ({ json: input }) };
  const code = fs.readFileSync(file, 'utf8');
  const fn = new Function('$', '$input', 'require', 'console', '$getWorkflowStaticData', 'return (async()=>{' + code + '})()');
  const logs = [];
  const estatico = {};
  const out = await fn($, $input, require, { error: m => logs.push(m), log: () => {} }, () => estatico);
  return { out, calls: calls.slice(), logs };
};
