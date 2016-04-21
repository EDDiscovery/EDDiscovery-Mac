# EDDiscovery-Mac
Mac version of EDDiscovery

This is a work in progress.

Before you compile it, you will need to edit  the source code and set:
- your ED log path
- your ESDM cmdr name
- your EDSM api key

At first launch, the application will:
1 - fetch all systems with known coordinates from EDSM
2 - parse all netlog files and create local jump database
3 - fetch your complete jump history form EDSM
4 - add missing jumps from EDSM to local jump database
5 - send to EDSM jumpa that are present only in the local jump database

If you have a large number of netlog files, this can take a few minutes, during which the application will be unresponsive.

At subsequent launches, the application will:
1 - fetch new systems from EDDB
2 - parse new jumps from netlog files
3 - sync new jumps from / to EDSM

After launch and until it is running, the application will:
1 - monitor your netlog files for new jumps in real time
2 - request system information for newly visited systems in real time from EDSM
3 - add newly visited to your EDSM jump history in real time

All this is done automatically without user interaction. In fact, the application has no GUI at all apart from a logging window.

TODO:
1 - add a jump list screen like the one on EDDiscovery for Windows
2 - add the ability to sync system notes form / to EDSM
3 - add a trilateration screen like the one on EDDiscovery for Windows and integrate it with EDSM
4 - ...
