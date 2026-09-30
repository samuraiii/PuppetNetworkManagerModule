# Contributing

Issues and pull requests are welcome: https://github.com/samuraiii/PuppetNetworkManagerModule

- Run the checks before you send a change, they are the same as in `.github/workflows/ci.yml`, see the
  [Development](README.md#development) section of the README (metadata lint, `rake syntax lint`, `rake spec`).
- The module supports Puppet 6 - 8 and OpenVox 7 - 8 (Ruby 2.7 and newer), OpenVox 9 is tested as a release candidate, do not use newer syntax than the
  existing code does.
- Add a spec for a change of the behaviour and describe it in `CHANGELOG.md` and, where it applies, in
  `README.md` and `REFERENCE.md`.
- Keep the secrets (passwords, keys) out of the issues, the logs and the specs.
- Security problems are reported privately, see [SECURITY.md](SECURITY.md).
- Contributions prepared with the help of AI tools are welcome under the conditions in the
  [Use of AI tools](README.md#use-of-ai-tools) section of the README.

## Releasing

A tag `vX.Y.Z` (or `vX.Y.Z-rc1`) on the `main` branch publishes the release to the
[Puppet Forge](https://forge.puppet.com/modules/samuraiii/networkmanager) and to the GitHub releases
(`.github/workflows/release.yml`). The workflow refuses the release when

- the tag is not the version of `metadata.json` (`v` + `version`),
- the tagged commit is not on `main` or its CI checks did not pass,
- `CHANGELOG.md` has no `## <previous version> -> <version>` section (it is the text of the GitHub release).

To release:

1. Set the `version` in `metadata.json` and rename the `## Unreleased` section of `CHANGELOG.md`
   to `## <previous version> -> <version>`, send it as a pull request and merge it.
2. Tag the merge commit and push the tag: `git tag -a vX.Y.Z -m "Release X.Y.Z" && git push origin vX.Y.Z`.

The Forge API key is the secret `PUPPET_FORGE_API_KEY` of the `forge` environment (only tags `v*` may use it).
The tags `v*` can not be moved or deleted (a ruleset), the files that are not for the Forge are the `export-ignore`
lines in `.gitattributes`. A version already on the Forge can not be published again, a failed release is fixed
by a new version.
