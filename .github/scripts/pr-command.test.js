const assert = require('node:assert/strict');
const fs = require('node:fs');
const workflow = fs.readFileSync('.github/workflows/terraform.yml', 'utf8');
const source = workflow.split('script: &authorize-command |\n')[1].split('\n  checks:')[0]
  .split('\n').map(line => line.replace(/^            /, '')).join('\n');
const run = new (Object.getPrototypeOf(async function () {}).constructor)('github', 'context', 'core', source);
async function command(options = {}) {
  const outputs = {};
  const context = {eventName: 'issue_comment', repo: {owner: 'owner', repo: 'repo'}, payload: {
    comment: {body: options.body || '/plan', user: {login: 'operator'}},
    issue: {number: 7}, repository: {full_name: 'owner/repo'}
  }};
  const reviews = options.reviews || [{user: {login: 'reviewer'}, state: 'APPROVED', commit_id: 'head'}];
  const github = {rest: {
    repos: {getCollaboratorPermissionLevel: async ({username}) => ({data: {permission: username === 'operator' ? options.permission || 'write' : 'write'}})},
    pulls: {get: async () => ({data: {state: 'open', draft: false, user: {login: 'author'}, head: {sha: 'head', repo: {full_name: 'owner/repo'}}, ...options.pr}}), listReviews: () => {}}
  }, paginate: async () => reviews};
  process.env.EXPECTED_SHA = options.expected || '';
  await run(github, context, {setOutput: (key, value) => outputs[key] = value});
  return outputs;
}
(async () => {
  const dispatch = {};
  Object.assign(process.env, {INPUT_OPERATION: 'apply', INPUT_TARGET: 'test', INPUT_PR: '12'});
  await run({}, {eventName: 'workflow_dispatch', sha: 'default-sha'}, {setOutput: (key, value) => dispatch[key] = value});
  assert.deepEqual(dispatch, {operation: 'apply', target: 'test', pr: '12', sha: 'default-sha'});
  for (const operation of ['plan', 'apply', 'destroy']) {
    assert.deepEqual(await command({body: `/${operation}`}), {operation, target: 'dev', sha: 'head', pr: 7});
    assert.equal((await command({body: `/${operation} prod`})).target, 'prod');
  }
  await assert.rejects(command({body: '/apply all'}), /Use \/plan/);
  await assert.rejects(command({body: '/destroy dev\necho injected'}), /Use \/plan/);
  await assert.rejects(command({permission: 'read'}), /write access/);
  await assert.rejects(command({pr: {state: 'closed'}}), /open, non-draft/);
  await assert.rejects(command({pr: {draft: true}}), /open, non-draft/);
  await assert.rejects(command({pr: {head: {sha: 'head', repo: {full_name: 'fork/repo'}}}}), /this repository/);
  await assert.rejects(command({expected: 'old'}), /PR changed/);
  await assert.rejects(command({reviews: []}), /needs approval/);
  for (const state of ['DISMISSED', 'CHANGES_REQUESTED']) {
    await assert.rejects(command({reviews: [
      {user: {login: 'reviewer'}, state: 'APPROVED', commit_id: 'head'},
      {user: {login: 'reviewer'}, state, commit_id: 'head'}
    ]}));
  }
  await assert.rejects(command({reviews: [{user: {login: 'reviewer'}, state: 'APPROVED', commit_id: 'old'}]}), /needs approval/);
  await assert.rejects(command({reviews: [{user: {login: 'author'}, state: 'APPROVED', commit_id: 'head'}]}), /needs approval/);
  delete process.env.EXPECTED_SHA;
  console.log('PR command authorization tests passed');
})().catch(error => {console.error(error); process.exit(1);});
