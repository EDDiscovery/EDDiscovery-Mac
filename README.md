# EDDiscovery-Mac
Mac version of EDDiscovery

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

If you have a large number of netlog files, this can take a few minutes. Subsequent launches should be much faster.

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
- add / edit / remove comments (changes will be synced to EDSM)
- see submitted distances from other systems (suspicious distances will be marked in red)
- trilaterate systems by adding distances to system with known coordinates
- submit distances to EDSM
- see a 2D map of your travel history, with markers for systems with user notes
- see a 2D map of your travel history, with markers for systems with user notes
- configure the screenshots dir for your ED installation

If you choose to configure the screenshots dir, EDDiscovery will:
- parse the contents and the directory
- match them against your travel history
- rename the files in PNG format, using timestamp and system name as file names
- monitor the directory for changes and manage newly added files accordingly
- display miniatures of the screenshots from within EDDiscovery
