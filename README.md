# alfred-install-workflow

This is a helper script to make it easier to install workflows from
development sources.

## Usage:

`install-workflow.sh` takes one or more files, which it treats as
resources that should be installed into the root of the workflow. It
also requires that the current directory have an `info.plist` file for
the workflow, and optionally an `icon.png`. If this workflow is already
installed, it will overwrite the existing workflow. Otherwise it will
install the workflow with a new UUID.

From a `Makefile` you might do the following:

```make
script:
    # compile your script here ...

install: script
    ./alfred-install-workflow/install-workflow.sh script
.PHONY: install
```

---

When developing a workflow, you can use the flag `--update-plist` to
copy the `info.plist` file from the installed workflow into the local
folder.
