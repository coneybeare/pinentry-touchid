# pinentry-touchid

A barebones pinentry for macOS using Touch ID and Keychain.

Build it:

```sh
swiftc main.swift -o ~/.local/bin/pinentry-touchid
```

Save your key passphrase to Keychain:

```
$ pinentry-tem
OK. hello
setpass
OK. Password set to default value 'SUPERSECURE'. Change it using Keychain Access ASAP
```

Set GnuPG pinentry program:

```sh
echo "pinentry-program ${HOME}/.local/bin/pinentry-tem" >> ~/.gnupg/gpg-agent.conf
# or replace the existing entry
```

Reload the agent and check that everything works:

```sh
gpg-connect-agent reloadagent /bye
echo 'hello world' | gpg -as
```
