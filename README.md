Synqa
=====

by Philip Dorrell

**Synqa** is a simple file syncing tool that works over SSH, and is designed
primarily for maintaining static websites. It uses a hash function to
determine which files don't need to be copied because the destination copy
is already identical to the source copy.

I wrote it for two main reasons:

* I couldn't get **rsync** to work on the combination of Cygwin and my
hosting provider, and the rsync error messages were not very informative.
* It was an opportunity to learn about SSH and how to use SSH and SCP with Ruby.

Dependencies of **synqa** are: 

* Ruby 1.9.2
* An SSH client. I use **plink**.
* An SCP client. I use **pscp**.

For some sample code, see **examples/synga-useage.rb** and **examples/sample-rakefile**.

Licence
-------

Synqa is licensed under the GNU General Public License version 3.

Notes and Issues
----------------

* **Synqa** has not been tested (or even designed to work) with file names
containing whitespace or non-ASCII characters. Typically this doesn't matter for
many static websites, but it will reduce the tool's usefulness as a general purpose
backup tool.
