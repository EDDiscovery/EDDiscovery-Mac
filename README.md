# EDDiscovery-Mac
Mac version of EDDiscovery

This is a work in progress.

Needless to say, you need to enable verbose logging on your ED installation.

At first launch, you should set:
- your CMDR name
- your ED log path
- your EDSM api key

After configuring your data, the application will:
- fetch all systems with known coordinates from EDSM
- parse all netlog files and create local jump database
- fetch your complete jump history form EDSM
- fetch all your comments from EDSM
- add to local database any jumps present only on EDSM
- send to EDSM any jumps present only in the local database

If you have a large number of netlog files, this can take a few minutes, during which the application will be unresponsive. Subsequent launches should be much faster.

At subsequent launches, the application will:
- fetch new systems from EDSM
- fetch new comments FROM EDSM
- parse new jumps from netlog files
- sync new jumps from / to EDSM

After launch and while it is running, the application will:
- monitor your netlog files for new jumps in real time
- add new jumps to your EDSM jump history in real time
- request system information for new jumps in real time from EDSM

All this is done automatically without user interaction.

UI side, at present you can:
- switch between different commanders (each will have its own settings and data)
- add / delete commanders
- browse your jump history
- select single jumps and see system information
- add / edit / removed comments (changes will be synced to EDSM)
- see submitted distances from other systems (suspicious distances will be marked in red)

TODO:
- add a trilateration screen like the one on EDDiscovery for Windows and integrate it with EDSM
- screenshots management
- ...
