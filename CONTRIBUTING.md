# Contributing

Thanks for helping. This is a small hobby kit, so keep changes small and easy to review.

## Good first contributions

- Test on your own pad and report what works or breaks (open an issue with your macOS version and what you saw).
- New OLED icons (16x16, see `firmware/source/togkey/pad_plus/keymaps/generic/icons.h`).
- Example configs for other apps or workflows in `mac/`.
- Docs fixes.

## Rules

- **U.S. English** in code, comments, docs, commits and PRs.
- **One change per PR.** Say what changed and why in plain prose. Say how you tested it and on what hardware.
- **Adding an icon:** add it to `icons.h`, add its name to `iconNames` in `mac/padkeys.swift` in the same position, and list it in `README.md` and `CLAUDE.md`. The two lists must stay in sync.
- **Firmware changes:** rebuild with `firmware/BUILD.md`, and replace `firmware/togkey_pad_plus_generic.uf2` in the same PR. Say what you flashed and tested. Firmware stays GPL-2.0-or-later.
- **Never commit** flash dumps (`picotool save -a`), personal configs or tokens.
- Keep it simple: no new dependencies unless there is no other way.

## Using Claude

`CLAUDE.md` tells Claude how this repo works. Open the repo in Claude Code and ask it to make your change. You still own the PR: read the diff and test it on your pad before you open it.

## License

Contributions outside `firmware/` are MIT (see `LICENSE`). Contributions inside `firmware/` are GPL-2.0-or-later.
