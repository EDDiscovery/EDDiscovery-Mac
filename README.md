# EDDiscovery-Mac
Mac version of EDDiscovery

This is a work in progress.

Before you compile it, you will need to edit the source code and set:
- your ED log path
- your ESDM cmdr name
- your EDSM api key

Needless to say, you need to enable verbose logging on your ED installation.

At first launch, the application will:
- fetch all systems with known coordinates from EDSM
- parse all netlog files and create local jump database
- fetch your complete jump history form EDSM
- add to local database any jumps present only on EDSM
- send to EDSM any jumps present only in the local database

If you have a large number of netlog files, this can take a few minutes, during which the application will be unresponsive. Subsequent launches should be much faster.

At subsequent launches, the application will:
- fetch new systems from EDDB
- parse new jumps from netlog files
- sync new jumps from / to EDSM

After launch and while it is running, the application will:
- monitor your netlog files for new jumps in real time
- request system information for newly visited systems in real time from EDSM
- add newly visited to your EDSM jump history in real time

All this is done automatically without user interaction. In fact, the application has no GUI at all apart from a logging window.

TODO:
- add a jump list screen like the one on EDDiscovery for Windows
- add the ability to sync system notes form / to EDSM
- add a trilateration screen like the one on EDDiscovery for Windows and integrate it with EDSM
- ...
