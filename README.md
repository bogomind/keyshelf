# keyshelf

My accounts and their secrets, in one place, with the secrets encrypted.

- `inventory.json` — what accounts exist, usernames, sign-in method, 2FA and recovery
  status, notes. Plain JSON, but it lists account names, so mine lives in the private
  config repo.
- `vault.sops.json` — the actual secret values, encrypted with [sops] + [age].
- `keyshelf` — a small CLI (Python stdlib) to list, show, reveal, copy, set, edit and
  remove entries, plus `doctor` to catch rot.

Written for one person with one machine: no server, no daemon, no database.

This repo is the tool. My live shelf (inventory + vault + `.sops.yaml`) lives in my
private NixOS config repo, `/etc/nixos/keyshelf`; `inventory.example.json` here shows
the shape.

## Why

Plain files in `~/.secrets` work until there are ten of them and nobody remembers which
account has which recovery path. This replaces "a folder of 600-mode files" with a
readable inventory plus one encrypted blob, so the *map* is legible and the *values*
are not lying around.

## Setup

```sh
sudo nixos-rebuild ...          # or: nix shell nixpkgs#sops nixpkgs#age nixpkgs#jq
./keyshelf init                 # creates ~/.config/sops/age/keys.txt
# put the printed public key into .sops.yaml (age:)
```

`init` refuses to overwrite an existing key; `--force` replaces it (old vault becomes
unreadable).

## Use

```sh
keyshelf list                       # accounts, how many secrets, 2FA state
keyshelf show github                # metadata only
keyshelf reveal github password     # print one secret
keyshelf reveal github              # print all fields as field=value
keyshelf copy github                # clipboard, if xclip is installed
printf %s "$pw" | keyshelf set github password
keyshelf edit github                # $EDITOR on that account's secrets
keyshelf add mail --name 'Mail' --username me --fields password,token
keyshelf totp github                # current authenticator code (TOTP)
keyshelf totp github -l             # same, with seconds left
keyshelf doctor                     # key perms, missing secrets, stale mirror
keyshelf materialize                # rebuild the plaintext mirror in ~/.secrets
```

`totp` works on any account with a `totp_secret` field, so I can keep authenticator
seeds in the same encrypted vault instead of a phone app. Standard RFC 6238, 6 digits,
30 seconds.

### The plaintext mirror

Some things insist on files: `bogo-secret`, the Telegram bot token, the phone API token.
`materialize` writes those few files into `~/.secrets` (mode 600) from the vault. They
are *derived* — the vault is the source of truth, and `doctor` complains when the mirror
is older than it.

The shelf directory defaults to `/etc/nixos/keyshelf` when it exists, otherwise to this
repo. Point it anywhere with `KEYSHELF_DATA`, or override single files with
`KEYSHELF_INVENTORY` / `KEYSHELF_VAULT` (the test uses a throwaway directory).
`SOPS_AGE_KEY_FILE` overrides the key path.

## Threat model, honestly

- Encrypted at rest. The repo can be public; without the age private key the vault is
  noise.
- **One key is one point of failure.** If `~/.config/sops/age/keys.txt` is lost, the
  vault is lost. Keep a copy somewhere that is not this machine (a phone is fine,
  a public repo is not).
- Anything that can read the key *and* run as me can read every secret. sops/age does
  not stop malware, it stops casual `cat` and leaked backups.
- Decrypted values are passed through pipes/temp files: `$EDITOR` in `keyshelf edit`
  writes plaintext to a 600 temp file in `/tmp` while editing, and `xclip` leaves the
  clipboard readable by any process of mine.
- Secrets reach `sops` through a short-lived staging file because sops needs a path
  whose name matches the creation rule; the file is deleted afterwards.
- Bot tokens and a card number are in here. The card is Vincent's, so losing the key
  is a real problem, not only an inconvenience.

## Files

```
keyshelf               the CLI
inventory.example.json shape of the account metadata
tests/smoke.sh         round-trip test in a throwaway shelf
# not in this repo (private): inventory.json, vault.sops.json, .sops.yaml
```

MIT.

[sops]: https://getsops.io/
[age]: https://age-encryption.org/
