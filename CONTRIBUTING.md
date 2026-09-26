# Contributing to ScreenChest

Thanks for taking the time to contribute! Bug reports, feature ideas,
documentation fixes and code are all welcome.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting bugs and requesting features

- Search [existing issues](https://github.com/Darna-Digital/screenchest/issues)
  first — someone may have reported it already.
- Open a [bug report](https://github.com/Darna-Digital/screenchest/issues/new?template=bug_report.yml)
  or a [feature request](https://github.com/Darna-Digital/screenchest/issues/new?template=feature_request.yml)
  using the templates. For bugs, include your ScreenChest version
  (**ScreenChest → About ScreenChest**), your macOS version, your Mac model and
  the steps that reproduce it.
- Found a security issue? Don't open a public issue — follow
  [SECURITY.md](SECURITY.md).

## Setting up the project

You'll need a Mac on macOS 26 with Xcode 26 (Swift 6.2). Build and open the app
with:

```bash
make run
```

Or keep it rebuilding and relaunching on every save:

```bash
scripts/watch.sh
```

macOS ties the Screen Recording grant to the app's signature, so an ad-hoc
signed build asks for it again after every rebuild. Create a local signing
identity once and the build scripts use it from then on:

```bash
scripts/create-signing-identity.sh
```

The [README](README.md#development) describes how the source is laid out.

## Making a change

1. Fork the repository and create a branch from `main`.
2. Keep the change focused: one fix or feature per pull request.
3. Match the style of the code around it, and make sure the tests pass:

   ```bash
   swift test
   ```

4. Make sure the app bundle still builds:

   ```bash
   make app
   ```

5. For changes to the website in [`www`](www), run its checks:

   ```bash
   pnpm --dir www lint
   ```

   ```bash
   pnpm --dir www format:check
   ```

   ```bash
   pnpm --dir www typecheck
   ```

6. Include screenshots or a short screen recording for anything visible in the
   UI — light and dark appearance if the change affects both. For changes to
   recording, rendering or export, attach a short exported clip if you can.
7. Open a pull request against `main` and fill in the template.

CI builds `ScreenChest.app` and runs the tests on a macOS 26 runner for every
pull request that touches the app, and lints and typechecks the website for
pull requests that touch `www`.

## Releases

Maintainers cut releases by bumping `VERSION` on `main`; GitHub Actions
builds, signs, notarizes and publishes them. See [RELEASING.md](RELEASING.md).

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
