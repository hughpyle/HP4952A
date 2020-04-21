# Remote protocol

The 'Remote/Printer' serial port on the analyzer can be used to connect to a remote controller or remote analyzer; or to a printer.

## Utilities Disk

The [PC Utilities Disk 1](http://www.hpmuseum.net/display_item.php?sw=597) includes a few DOS applications that can be used to work with menu-files, event(?) files, and disks.  The `5XREMOTE.EXE` application is a remote control application that can operate the 4952A remotely.

[Here](https://hackaday.io/project/163027-hp-4952a-turned-general-purpose-cpm-machine/log/158754-getting-programs-to-your-4952) is a short writeup of how to do that.

![5XREMOTE-1](5xremote-screen1.png)

Remote functions include:
* Get the remote device's ID.
* Reset the analyzer.
* Upload an application (from the analyzer to the PC).
* Download an application (from the analyzer to the PC).
* Upload and download custom menus.
* Display timers and counters.
* Upload and download captured data.
* Run applications on the analyzer.

![5XREMOTE-1](5xremote-screen2.png)

## The Remote Protocol

Using [interceptty](https://github.com/geoffmeyers/interceptty) I've captured a few of the commands.

Haven't made sense of them yet...


