'use strict';
// Run the actual Swift-embedded reader against changing website DOM fixtures.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('Lekapro/FingerprintHomepage.swift', 'utf8');
const code = source.match(/#"""\r?\n([\s\S]*?)\r?\n\s*"""#/)[1];
const id = 'AAAAAAAAAAAAAAAAAAAA';
const agent = {visitor_id:id,event_id:'fixture-event',cache_hit:false};
const server = {identification:{visitor_id:id},event_id:'fixture-event',environment_id:'fixture-env'};
let pre = [], tabs = [], toggles = 0, clicks = [];
const document = {
  body:{innerText:`Hello, visitor ID\n${id}`},
  querySelectorAll(kind) { return kind === 'pre' ? pre : kind === 'li' ? tabs : []; },
  getElementById(name) {
    assert.equal(name, 'toggle_homepage_developer_demo');
    return {click() {
      toggles++;
      document.body.innerText = 'Developer response panel';
      tabs = ['response.json','smartSignals.json'].map(name=>({
        textContent:name,className:'CodeWithSelectors-module--tab--fixture',
        click() {
          clicks.push(name);
          for (const tab of tabs) tab.className='CodeWithSelectors-module--tab--fixture';
          this.className+=' CodeWithSelectors-module--active--fixture';
          pre=[{textContent:JSON.stringify(name==='response.json'?agent:server)}];
        }
      }));
    }};
  }
};
const context = vm.createContext({document, location:{href:'https://fingerprint.com/'},
  navigator:{userAgent:'Fixture UA'}, performance:{timeOrigin:123}});
const read = name=>vm.runInContext(code.replace('__WANTED_TAB__', JSON.stringify(name)),context);
assert.equal(read('response.json').visitorID, id);
assert.equal(toggles,1);
assert.equal(read('response.json').agentResponse,undefined);
assert.equal(read('response.json').agentResponse.visitor_id,id);
assert.equal(clicks.length,1,'Reading an active tab must not keep toggling it');
read('smartSignals.json');
assert.equal(read('smartSignals.json').serverResponse.identification.visitor_id,id);
assert.equal(toggles,1,'Developer view must remain open');
assert.deepEqual(clicks,['response.json','smartSignals.json']);
document.body.innerText=`Visitor ID_\n${id}\nMarketing example`;
assert.equal(read('response.json').visitorID,null,'Static marketing ID must not be treated as the visitor');
document.body.innerText='Hello, visitor ID\nLoading visitor ID';
assert.equal(read('response.json').visitorID,null);
document.body.innerText=`Hello, visitor ID\n${id}\nHello, visitor ID\nBBBBBBBBBBBBBBBBBBBB`;
assert.equal(read('response.json').visitorID,null,'Ambiguous labels must fail closed');
pre=[{textContent:'loading'},{textContent:'{"loading":true}'},{textContent:'null'}];
assert.equal(read('smartSignals.json').serverResponse,undefined);
console.log('Homepage DOM reader regression: PASS');
