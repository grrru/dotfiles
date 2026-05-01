# mise

`install.sh` installs mise and configures zsh activation, but runtime versions are intentionally local.

Set global defaults on each machine:

```sh
mise use -g node@latest
mise use -g go@latest
mise use -g python@latest
```

Set project-specific versions from the project root:

```sh
mise use go@1.25
```

The local `mise/config.toml` file is ignored so global runtime choices do not become dotfiles changes.
