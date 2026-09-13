module.exports = async ({ github, context, fs }) => {
  const number = Number(process.env.PR_NUMBER);
  if (!Number.isSafeInteger(number) || number <= 0) throw new Error('Invalid PR number');
  await github.rest.pulls.get({ ...context.repo, pull_number: number });
  const target = process.env.TARGET;
  const phase = process.env.PHASE;
  const run = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
  let summary = '';
  const path = `environments/${target}/summary.json`;
  if (phase === 'plan' && fs.existsSync(path)) {
    const counts = JSON.parse(fs.readFileSync(path, 'utf8'));
    summary = `\nResources: **${counts.create} create**, **${counts.update} update**, **${counts.delete} delete**. Replacements count as create and delete.\n`;
  }
  const body = `### Terraform ${process.env.OPERATION}: ${target} — ${phase}\nStatus: **${process.env.RESULT}**\nCommit: \`${process.env.COMMIT_SHA || context.sha}\`\n${summary}\n[Review workflow output and approval details](${run})\n\n${phase === 'plan' ? 'Specify the environment and command together on an approved PR: dev //plan, test //apply, or prod //destroy. Valid environments: dev, test, pre, prod. Each comment targets one environment. Apply/destroy runs generate a saved plan and wait for configured deployment approval. Manual dispatch is also available.' : 'See the workflow logs for the result. This operation used the saved plan from this run.'}`;
  await github.rest.issues.createComment({ ...context.repo, issue_number: number, body });
};
