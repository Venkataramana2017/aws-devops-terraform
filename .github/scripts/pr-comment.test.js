const assert = require('node:assert/strict');
const comment = require('./pr-comment.js');

(async () => {
  const comments = [];
  const github = { rest: {
    pulls: { get: async () => ({}) },
    issues: { createComment: async body => comments.push(body) }
  }};
  const context = { repo: { owner: 'owner', repo: 'repo' }, serverUrl: 'https://github.com', runId: 123, sha: 'abc' };
  Object.assign(process.env, { PR_NUMBER: '5', TARGET: 'dev', PHASE: 'plan', OPERATION: 'plan', RESULT: 'success' });
  await comment({ github, context, fs: {
    existsSync: () => true,
    readFileSync: () => JSON.stringify({ create: 2, update: 1, delete: 0 })
  }});
  assert.match(comments[0].body, /2 create/);
  assert.equal(comments[0].issue_number, 5);
  Object.assign(process.env, { PHASE: 'execution', OPERATION: 'destroy', RESULT: 'failure' });
  await comment({ github, context, fs: {} });
  assert.match(comments[1].body, /destroy/);
  assert.match(comments[1].body, /failure/);
  process.env.PR_NUMBER = 'invalid';
  await assert.rejects(comment({ github, context, fs: {} }), /Invalid PR/);
  console.log('PR comment tests passed');
})().catch(error => { console.error(error); process.exit(1); });
