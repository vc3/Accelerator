Shell Out
=========

Shell out to another process to run an exectable application and return the
result and/or output.

Usage
-----

`PS> Invoke-Application -FilePath C:\Windows\System32\notepad.exe -Arguments ""`

NOTE: Currently the full path must be specified for some commands. In this case
there are multiple 'notepad' commands found, which would make the call ambiguous
unless the full path is specified.
