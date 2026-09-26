# Security Policy

## Supported versions

Only the latest version of ScreenChest receives security fixes. Make sure
you're on the newest build before reporting.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report it privately through
[GitHub's vulnerability reporting](https://github.com/Darna-Digital/screenchest/security/advisories/new)
instead. Include:

- what the issue is and what an attacker could do with it,
- the ScreenChest and macOS versions affected,
- steps or a proof of concept that reproduce it.

We'll acknowledge the report within a few working days, keep you updated while
we work on a fix, and credit you in the release notes unless you'd rather stay
anonymous.

## Scope

ScreenChest records your screen, camera, microphone and system audio, tracks
your cursor, and keeps every recording as plain files in your Movies folder.
Issues that let it capture anything you didn't ask it to, keep recording after
you stop, write recordings anywhere but where you chose, or let a crafted
`.screenchest` package run code or read files outside itself when opened are
especially in scope.
