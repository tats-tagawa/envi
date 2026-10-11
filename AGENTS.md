# Agent rules

## Keep README current

After every edit that affects user-facing behavior, review [README.md](README.md) and update it so documented behavior matches the app.

README structure:

1. Start with general instructions for how to **search**, **open**, **create**, **delete**, and **rename** notes (the **Getting started** section).
2. Only then cover deeper detail (search model, list, tags, shortcuts, settings, Vim, and so on).

## Prefer clear, readable code

Favor simple, understandable implementations over clever or complex ones. Match existing project style; avoid unnecessary abstraction or density that hurts readability.

## Never commit to main directly

Do not commit to `main`. Make changes on a feature branch, open a pull request, and merge the PR (or ask the user to merge). Do not push commits straight onto `main`.
