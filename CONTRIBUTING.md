# Contributing

Issues and pull requests are welcome: https://github.com/samuraiii/PuppetNetworkManagerModule

- Run the checks before you send a change, they are the same as in `.github/workflows/ci.yml`, see the
  [Development](README.md#development) section of the README (metadata lint, `rake syntax lint`, `rake spec`).
- The module supports Puppet 6 - 8 and OpenVox 7 - 8 (Ruby 2.7 and newer), do not use newer syntax than the
  existing code does.
- Add a spec for a change of the behaviour and describe it in `CHANGELOG.md` and, where it applies, in
  `README.md` and `REFERENCE.md`.
- Keep the secrets (passwords, keys) out of the issues, the logs and the specs.
- Security problems are reported privately, see [SECURITY.md](SECURITY.md).
- Contributions prepared with the help of AI tools are welcome under the conditions in the
  [Use of AI tools](README.md#use-of-ai-tools) section of the README.
