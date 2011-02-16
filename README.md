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

For some sample code, see **synga-example.rb**.

Licence
-------

Synqa is licensed under the GNU General Public License version 3.

Notes and Issues
----------------

* Although functional, this project is work in progress, and in 
particular there are some simple caching options which need to be added
to make it practical to use for medium size sites.
* **Synqa** has not been tested (or even designed to work) with file names
containing whitespace or non-ASCII characters. Typically this doesn't matter for
many static websites, but it will reduce the tool's usefulness as a general purpose
backup tool.
* There is not yet any error checking on invoking SSH or SCP clients (i.e. no
exception is raised if a client process returns an error code).
