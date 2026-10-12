# Security policy

The current `main`, `shader`, `particle-effect`, `post-process` and
`rising-water` branches are the maintained teaching versions.

## Report a vulnerability

Use **Security > Report a vulnerability** on the public catchup repository to
send a private report to the maintainer. Include the affected branch, relevant
files and steps to reproduce the issue. Do not post credentials, student
personal information or exploit details in a public issue or PR.

For ordinary setup or gameplay questions, use the AGP Teams channel.

## Maintenance

The public teaching branches are protected against deletion and force pushes.
Changes go through maintainer review and automated build/security checks.
The owner can bypass review requirements when merging their own maintenance
PRs. Only trusted repository administrators should have write access.

Secret scanning, push protection, dependency alerts and CodeQL scans support
ongoing maintenance. Automated security updates propose changes for review;
they do not merge automatically. Known vulnerable .NET Core 1.0 dependencies
were removed from the content builder by pinning its SharpDX compiler packages
to 4.2.0, while keeping the teaching version of MonoGame pinned.

Students should keep their own assessment work in their private repositories.
GitHub settings and branch protections belong to this public repository and
are not copied when students clone and push to a new independent repository.
The CodeQL workflow skips private copies so it does not require students to
purchase private-repository code scanning.
