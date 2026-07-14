# secrets/

This folder is git-ignored (except this README). Put credentials here — they are
never committed or pushed.

## kie.ai API key

Create a file `secrets/kie_key.txt` containing ONLY your kie.ai API key (one line,
no quotes, no `Bearer` prefix). The asset-generation scripts in `tools/` read the
key from this file; it is never printed or committed.

    secrets/kie_key.txt      <- your key, one line

Get / regenerate a key at https://kie.ai/api-key
