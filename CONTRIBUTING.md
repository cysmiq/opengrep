# Introduction

Thank you for your interest in contributing to the Opengrep source code!

Please ensure you have read the `README.md` and `CODE_OF_CONDUCT.md` documents.

# Contribution guidelines

### Semi-linear history with merge commits

We prefer a semi-linear git history with merge commits. This means that PR 
authors should try to ensure that their branches are rebased on top of the 
target branch, which in most cases will be `main`.

Therefore, a merge commit is created for every merge, but the branch is only 
merged if a fast-forward merge is possible. This ensures that if the merge 
request build succeeded, the target branch build also succeeds after the merge.

As a corrolary of the above: please do not merge `main` into your PR branch.

In the CYSMIQ fork, an upstream synchronization may import the original
`opengrep/opengrep` history with a merge commit whose first parent is the
current fork `main` and whose second parent belongs to upstream `main`.
The history check verifies these parents against the original repository;
other fork-owned merge commits still require a rebase. This preserves
upstream commit identities and our fork fixes without rewriting either history.

### Clean and informative commits

Contributors are requested to submit PRs with a well-organised, clean sequence 
of commits. This ensures that we can trace changes in case of issues and more 
generally that we can pinpoint when changes have been made.

If a commit is closing an issue, please mention the issue number in the commit 
message.

When a PR is marked open for review, it is expected that the commit history will 
be in a clean, informative state. It's ok to rewrite history in _your_ branch 
while you are working on a PR, assuming all PR authors are synchronised about this 
kind of operation.

Also, remember that smaller PRs make life easier for everyone and will allow 
your contributions to be merged in faster.

### Tests

All new features should include appropriate tests, and all CI test workflows 
must pass.

### Informative PR descriptions

Please ensure that reviewers have all the information needed to evaluate your 
contribution. 

This includes: 

- a detailed description of what you are contributing; 
- the justification for the feature or change, for example which issue(s) are 
  being closed; 
- when necessary, recommendations to reviewers in order to help them do a good 
  job in reviewing your contributions.
