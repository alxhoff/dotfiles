# Selected packages

Run on your **current** machine:

```bash
../export-inventory.sh
../select-packages.sh --merge-recommended
```

That creates `*.list` files here. Commit them to git so `install-packages.sh` can use them on EndeavourOS.
