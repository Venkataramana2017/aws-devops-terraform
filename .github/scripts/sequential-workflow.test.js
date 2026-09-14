const assert = require('node:assert/strict');
const fs = require('node:fs');
const workflow = fs.readFileSync('.github/workflows/terraform.yml', 'utf8');
const stages = ['dev', 'test', 'pre', 'prod'];
const jobs = Object.fromEntries([...workflow.matchAll(/^  (\w+):\n([\s\S]*?)(?=^  \w+:\n|$(?![\s\S]))/gm)]
  .map(([, name, body]) => [name, body]));
function allowed(name, operation, selected, results = {}, event = 'workflow_dispatch', cancelled = false) {
  const needs = {
    request: {result: 'success', outputs: {operation}},
    checks: {result: 'success', outputs: {environments: JSON.stringify(selected)}}
  };
  for (const stage of stages) {
    for (const phase of ['plan', 'execute']) needs[`${stage}_${phase}`] = {result: 'success'};
  }
  for (const [job, result] of Object.entries(results)) needs[job].result = result;
  const expression = jobs[name].match(/^    if: \$\{\{ (.*) \}\}$/m)[1];
  const github = {event_name: event, repository: 'owner/repo', event: {pull_request: {head: {repo: {full_name: 'fork/repo'}}}}};
  return Function('needs', 'github', 'cancelled', 'contains', 'fromJSON', `return ${expression}`)(
    needs, github, () => cancelled, (list, value) => list.includes(value), JSON.parse);
}
for (const [i, stage] of stages.entries()) {
  assert.match(jobs[`${stage}_plan`], new RegExp(`environment: ${stage}-plan`));
  assert.match(jobs[`${stage}_execute`], new RegExp(`environment: ${stage}\\n`));
  if (i) assert.match(jobs[`${stage}_plan`], new RegExp(`needs: \\[request, checks, ${stages[i-1]}_plan, ${stages[i-1]}_execute\\]`));
  for (const operation of ['plan', 'apply', 'destroy']) {
    for (let last = 0; last < stages.length; last++) {
      assert.equal(allowed(`${stage}_plan`, operation, stages.slice(0, last + 1)), i <= last);
    }
    assert.equal(allowed(`${stage}_execute`, operation, stages), operation !== 'plan');
    for (const result of ['failure', 'cancelled', 'skipped']) {
      assert.equal(allowed(`${stage}_execute`, operation, stages, {[`${stage}_plan`]: result}), false);
      if (i) {
        const previous = `${stages[i-1]}_${operation === 'plan' ? 'plan' : 'execute'}`;
        assert.equal(allowed(`${stage}_plan`, operation, stages, {[previous]: result}), false);
      }
    }
    for (const phase of ['plan', 'execute']) {
      assert.equal(allowed(`${stage}_${phase}`, operation, stages, {}, 'workflow_dispatch', true), false);
    }
  }
  // Plan-only runs must progress despite the intentionally skipped execution job.
  if (i) assert.equal(allowed(`${stage}_plan`, 'plan', stages, {[`${stages[i-1]}_execute`]: 'skipped'}), true);
  assert.equal(allowed(`${stage}_plan`, 'plan', stages, {}, 'pull_request'), false);
  assert.equal(allowed(`${stage}_execute`, 'apply', stages, {}, 'push'), false);
}
console.log('Sequential workflow gating tests passed');
