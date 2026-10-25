# 2026-10 security incident — forged commits pushed with a compromised GitHub account

**Status:** contained; every affected branch was restored by [the-watcher](https://github.com/fiqryq/the-watcher), the automated guard on this account (as of 2026-10-25)
**Affected repo:** `fiqryq/opentmux` (1 branch: `main`)
**Other repos:** 45 more repos owned by `fiqryq` were hit the same way
**First malicious push here:** 2026-10-19 17:26 UTC · **last restored:** 2026-10-25 08:06 UTC

## Summary

Someone holding a working credential for the `fiqryq` GitHub account force-pushed forged
commits over the newest commit of branches in this repo, in all 3 waves described
below. Each forgery kept the original commit's author, author date and parent, and usually its
message, so in `git log` it looks like ordinary work. Only its files differ: they add malware
that runs by itself as soon as the folder is opened in VS Code (or Cursor), with no prompt.

GitHub logged every malicious push as the `fiqryq` account, so the push used a real credential
of that account (an OAuth app, a token or a session), not a collaborator's. Which credential is
still being determined; this report will be updated.

## This repo

| Branch | Wave | Pushed (UTC) | Forged commit | Replaced | Restored (UTC) | How |
|---|---|---|---|---|---|---|
| `main` | 1 | 2026-10-19 17:26 | [`eeee6cb`](https://github.com/fiqryq/opentmux/commit/eeee6cb58e95c1872c914a8fffc6b8a6f1bd8be1) | [`ef26618`](https://github.com/fiqryq/opentmux/commit/ef266180acea5162fffe6f400341377da095ba47) | 2026-10-20 08:30 | fix commit [`577d74e`](https://github.com/fiqryq/opentmux/commit/577d74e11bb127b0cab46499dc397150ac21ac5a) |
| `main` | 2 | 2026-10-25 05:25 | [`25b7f3c`](https://github.com/fiqryq/opentmux/commit/25b7f3cce31bc1d170881530e421744ee6bae6cf) | [`1b9637f`](https://github.com/fiqryq/opentmux/commit/1b9637f122e4e4eae1fa2b41bb5199faea755bce) | 2026-10-25 06:26 | reset to [`1b9637f`](https://github.com/fiqryq/opentmux/commit/1b9637f122e4e4eae1fa2b41bb5199faea755bce) |
| `main` | 3 | 2026-10-25 08:04 | [`25b7f3c`](https://github.com/fiqryq/opentmux/commit/25b7f3cce31bc1d170881530e421744ee6bae6cf) | [`1b9637f`](https://github.com/fiqryq/opentmux/commit/1b9637f122e4e4eae1fa2b41bb5199faea755bce) | 2026-10-25 08:06 | reset to [`1b9637f`](https://github.com/fiqryq/opentmux/commit/1b9637f122e4e4eae1fa2b41bb5199faea755bce) |

Files the forged commits added or changed:

| Path | Purpose |
|---|---|
| `.gitignore` | changed so `.env` is no longer ignored |
| `.vscode/settings.json` | turns on `task.allowAutomaticTasks` so the task runs without asking |
| `.vscode/tasks.json` | hidden VS Code task (`eslint-check`, `runOn: folderOpen`) that runs the fake font with Node |
| `scripts/agents/public/fonts/` | 16 real Font Awesome files and a README, as cover for the payload |
| `scripts/agents/public/fonts/fa-brand-400.orc` | **the payload**: obfuscated JavaScript posing as a font |
| `scripts/agents/public/fonts/fa-brand-400.woff` | **the payload**: obfuscated JavaScript posing as a font |

## Indicators of compromise

| Item | Value |
|---|---|
| Payload file | `fa-brand-400.woff` (wave 1), `fa-brand-400.orc` (waves 2–3), inside a `public/fonts/` folder of real Font Awesome files |
| Payload git blob | `92c7a45d384b0102905af1cdbf34ec9595c19d73` (`.woff`), `663e5554b1e1e00b30f68cd3a887446df55d76a7` (`.orc`) |
| Loader git blob | `70e6d951b02623fa79e12c28315cdac7c2cf23b4`, `a69be3f4942dffc10cc9567ca7b78ed12d234db7` (`api.js`) |
| Download URLs (base64 in `.env`) | `hxxps://files[.]catbox[.]moe/mnq9x9[.]js`, `hxxps://files[.]catbox[.]moe/g8leys[.]js` |
| VS Code task | label `eslint-check`, `"runOn": "folderOpen"`, `"hide": true`, `"reveal": "never"`; runs `node ./public/fonts/fa-brand-400.<ext>`, falling back to `where node` on Windows |
| Settings marker | `.vscode/settings.json` with `compile-hero.disable-compile-files-on-did-save-code` and a `lint on open` task |
| Forged author (waves 2–3) | `repo-guard <repo-guard@users.noreply.github.com>`, message `Remove planted malware`: copies of the guard's own fix commits |
| Commit signatures | none of the 232 forged commits carries a verified signature |
| Pushing account | `fiqryq` (the account owner's credential) |

## Timeline (UTC)

| When | What |
|---|---|
| Oct 19, 17:23–17:28 | Wave 1: 71 forged force-pushes across 45 repos, about 4 seconds apart |
| Oct 19, 20:34–20:36 | 16 of those branches force-pushed again with updated payloads |
| Oct 20, 02:15–09:11 | Payloads removed with fix commits; from 08:15 by the guard, then called repo-guard |
| Oct 25, 05:22–05:26 | Wave 2: 73 force-pushes across 46 repos, now forging the guard's fix commits (`repo-guard`, `Remove planted malware`) and putting the payload back. The guard's own repo is hit too |
| Oct 25, 06:24–06:27 | The guard resets all 73 branches to their last clean commit |
| Oct 25, 07:51 | SSH keys on the account replaced |
| Oct 25, 08:02–08:06 | Wave 3: 72 force-pushes re-installing the wave 2 forgeries, minutes after the guard's token was rotated. The new SSH key is not how they got in |
| Oct 25, 08:04–08:08 | The guard resets all 72 branches again |

## Did the malware run on your machine?

Only if, between a push and its restore in the table above, you **cloned or pulled one of those
branches and opened the folder in VS Code or Cursor** (the planted settings turn automatic tasks
on), or **ran an npm script** in it (`api.js` runs first). Nothing runs from just browsing the
repo on GitHub.

Check a clone:

```sh
git fetch origin
git log --all --format=%H | grep -E '25b7f3cce31b|eeee6cb58e95'
ls .vscode public/fonts 2>/dev/null
```

No output from `grep` means the forged commits never reached that clone. If they did, reset the
branch to `origin`, and if the folder was opened or an npm script ran in that window, treat the
machine as compromised: change the passwords saved in its browsers, move any crypto wallets,
revoke its GitHub tokens and SSH keys, and check it for unknown `node` processes and login items.

## Response

- Every affected branch restored (table above); the guard resets any repeat within its next run.
- SSH keys replaced, commit signing turned on, the guard's token rotated.
- A commit watcher now reports every push to every repo of the account, with who pushed it and
  whether each commit has a verified signature.
- Revoking every OAuth app, personal access token and session on the account, since one of
  those is what the attacker used.

## Lessons

1. **Author, date and message prove nothing.** All three are set by whoever makes the commit.
   The forgeries here copied them exactly, even from the guard's own commits.
2. **Sign commits and turn on vigilant mode.** None of the forgeries was signed, so with every
   real commit signed they show up as Unverified at a glance.
3. **A force-push on a branch nobody rebases is the signal.** Without branch protection (not
   available on free private repos) nothing blocks it, so something has to watch for it.
4. **Never let a repo run code on folder open.** Turn `task.allowAutomaticTasks` off in your own
   VS Code settings, and treat a `.vscode/tasks.json` with `runOn: folderOpen` in a repo you
   didn't write as hostile.
5. **Fonts and images that contain JavaScript** are never legitimate.
