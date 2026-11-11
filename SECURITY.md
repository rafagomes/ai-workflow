# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public issue.**

Instead, use [GitHub's private vulnerability reporting](https://github.com/rafagomes/ai-workflow/security/advisories/new) to submit your report. This ensures the issue is handled privately until a fix is available.

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)

### What to Expect

- **Acknowledgment** within 48 hours
- **Status update** within 7 days
- **Fix or mitigation** as soon as practical, depending on severity

### Scope

This project is a configuration toolkit (markdown files, shell scripts, JSON config). Relevant vulnerabilities include:

- Command injection in `install.sh` or `uninstall.sh`
- Path traversal in symlink operations
- Sensitive data exposure through default configurations
- Skill or agent definitions that could lead to unintended code execution
- The CI workflow (`.github/workflows/ci.yml`): an over-broad token, an unpinned action, or a step that exposes secrets. CI is deliberately free-only, with no secrets, API keys or LLM calls

### Out of Scope

- Vulnerabilities in Claude Code itself — report those to [Anthropic](https://docs.anthropic.com/en/docs/claude-code)
- Issues in third-party dependencies not bundled in this repo (a pinned action or CLI version that has a known vulnerability is in scope: report it)

## Supported Versions

Only the latest version on the `main` branch is supported with security updates.
