# GlycoBase

A comprehensive database for glycans. The full GlycoBase dataset is stored in Synapse and can be downloaded [here](https://www.synapse.org/#!Synapse:syn21818556).

GlycoBase can be accessed online [here](https://wyss.shinyapps.io/glycobase/).

<br>

<p align="center">
<img src="https://cdn.brandfolder.io/TLCWDQBL/as/q8i4fx-140kc8-23ljuz/glycobase_demo.gif" width="800">
</p>

<br>

## Prerequisites

### System Requirements

* Python 3

* [virtualenv](https://virtualenv.pypa.io/en/latest/) (`pip install virtualenv`)

* R and RStudio

## Local Development Instructions

### Create the local virtual environment (first time set-up only)

The [`synapser` R package](https://github.com/Sage-Bionetworks/synapser) developed by Sage Bionetworks depends on the older `PythonEmbedInR` package, which has compatibility issues. For this reason, this app interacts with the Synapse API using the [Synapse Python client](https://python-docs.synapse.org/build/html/) and uses the R package `reticulate` to call that Python code via the Shiny server.

Use the `reticulate` package to create a Python 3 virtualenv and install the Python packages `pandas` into it. In the R console:

```
> reticulate::virtualenv_create(envname = 'python35_env',
                                python = '/usr/bin/python3')

> reticulate::virtualenv_install('python35_env',
                                 packages = c('synapseclient', 'requests', 'pandas'))
```

Note: We also include `synapseclient` and `requests`, which can be used to (optionally) require the user to log in using their Synapse credentials. This functionality it currently turned off. Additionally, avoid running `library(reticulate)` as this will cause `reticulate` to initialize in the R session with your system version of Python rather than the one specified in the `python` arg of `virtualenv_create()`. If this happens, you may see an error similar to:

```
ERROR: The requested version of Python ('~/.virtualenvs/python35_env/bin/python') cannot be used, as
another version of Python ('/usr/bin/python') has already been initialized.
```

If you see this error, restart your R session and run the two commands above to create your virtual environment.

### Running the app

In RStudio, open `app.py` and click the "Run App" button or run `shiny::runApp()` in the console. Open a web browser and go to `http://127.0.0.1:7450` to see the app.

## Secrets

Sensitive data like passwords and secret keys should never be checked into git in cleartext (unencrypted). If you need to store sensitive info, you can use the openssl cli to encrypt and decrypt the file.

### Encrypt a file with shared secret

```
$ openssl enc -aes256 -base64 -in .Renviron -out .Renviron.encrypted
```

### Decrypt a file with shared secret

```
$ openssl enc -d -aes256 -base64 -in .Renviron.encrypted -out .Renviron
```

<br>

## Additional Resources

* See the full [Synapse REST API docs](https://rest-docs.synapse.org/rest/index.html) for detailed explanations of all available endpoints.
