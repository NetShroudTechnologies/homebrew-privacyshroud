# homebrew-privacyshroud

Homebrew tap for [PrivacyShroud](https://privacyshroud.ai) — AI-powered data broker opt-out tool.

## Prerequisites

PrivacyShroud runs as an [OpenClaw](https://openclaw.ai) AI agent skill. OpenClaw must be installed and configured before PrivacyShroud will function.

See the [install guide](https://privacyshroud.ai/install) for step-by-step instructions.

## Install

```bash
brew tap netshroudtechnologies/privacyshroud
brew install privacyshroud
```

## Update (alpha)

Auto-update is not available during alpha. To get a new version:

```bash
brew reinstall privacyshroud
```

Your profile and run history will be preserved.

## Uninstall

```bash
brew uninstall privacyshroud
```

User data at `~/Documents/PrivacyShroud` and `~/.privacyshroud` is **not** removed automatically. To fully remove:

```bash
brew uninstall privacyshroud
rm -rf ~/Documents/PrivacyShroud ~/.privacyshroud
```

## Links

- Website: [privacyshroud.ai](https://privacyshroud.ai)
- User guide: [privacyshroud.ai/user-guide](https://privacyshroud.ai/user-guide)
- Source: [github.com/NetShroudTechnologies/PrivacyShroud](https://github.com/NetShroudTechnologies/PrivacyShroud)
- Feedback: support@privacyshroud.ai
