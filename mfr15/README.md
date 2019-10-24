# mfr
Being makers, we write our own code for running Maker Faire Rome. 
It's a large event with a high operational complexity due to exhibitor
handling, calendars, agreements, badges, exceptions etc.
In this repository we're sharing some of our code.

## Accreditation system

We have an exhibitor/maker accreditation office at the entrance of the faire, 
where thousands of people are doing their check-in and getting their badges.
Being a critical point of our operations we want the office to run even in case 
of network outages, and we don't want to use our main database server as a Single 
Point of Failure, since that database is critical for other things as well.
So we're going to have a local server running on a Beaglebone Black (yes, we
love Open Hardware), with continuous bidirectional synchronization to the main
database server. Full redundance.

## Scripts for graphics

We needed to generate graphics for booths, calendar, maker signs and other things,
so we wrote a few scripts.
