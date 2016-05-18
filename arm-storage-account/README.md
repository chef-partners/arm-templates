# Storage Account

The composability of ARM templates means that a template for the storage account can be called whether it needs to be created or not.

This folder contains two files which allow the storage account to be created or just "mocked" if it already exists.  This is worked out by the controlling template and will include the one that has `new` or `exists` in the file as defined when the main template is called.
