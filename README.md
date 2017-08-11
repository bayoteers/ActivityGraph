ActivityGrap Bugzilla Extension
===============================

This extension provides bug dependency graph which is color coded based on the
time since last activity on the bugs. The same color coded time since last
activity can also be added as a column in bug lists and the planning view
provided by AgileTools extension.


Installation
============

This extension requires [BayotBase](https://github.com/bayoteers/BayotBase)
extension, so install it first.

1.  Put extension files in

        extensions/ActivityGraph

2.  Run checksetup.pl

3.  Restart your webserver if needed (for exmple when running under mod_perl)

4.  Adjust the configuration values available in Administration > Parameters >
    ActivityGraph
