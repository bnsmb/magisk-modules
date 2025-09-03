# magisk-modules

This repository contains most of my Magisk Modules.

The binaries in the Magisk modules in this repository are for Android running on an **arm64** CPU.

There are some useful scripts for maintaining Magisk Modules in an adb shell in the directory **scripts**:
i
| Script | Description | comment |
| ---| ---| ---| 
| install_mm.sh  | install a Magisk Module via magisk binary in an adb shell | | 
| lmm   | list and maintain installed Magisk Modules | | 
| list_bind_mounts.sh  | list bind mounts created by Magisk for Magisk Modules | | 
| recreate_bind_mount.sh | update a file installed via Magisk Module without rebooting the phone | | 

| Binary | version | source code | comment |
| ---| ---| ---| ---|
| 7zz  | 25.00 | https://www.7-zip.org | statically linked | 
| gawk | 5.3.2 |  https://www.gnu.org/software/gawk/ | |
| bash | 5.2.37|  https://www.gnu.org/software/bash/ | dynamically linked for the Android OS libraries |
| bash-static | 5.2.37|  https://www.gnu.org/software/bash/ | statically linked |



**Update 15.08.2025**

Old versions of the Magisk modules are now in the sub directory [archive](Magisk_Modules/archive).

---

A repository with the Magisk Module with **clang version 19** is here:

[https://github.com/bnsmb/Magisk-Module-with-clang19](https://github.com/bnsmb/Magisk-Module-with-clang19)

(see [http://bnsmb.de/My_HowTos_for_Android.html#Documentation_for_the_Magisk_Module_with_clang19_and_the_NDK_r27b](http://bnsmb.de/My_HowTos_for_Android.html#Documentation_for_the_Magisk_Module_with_clang19_and_the_NDK_r27b) for the documentation for this Magisk Module)

---

A repository with a Magisk Module with **clang version 20** is here:

[https://github.com/bnsmb/clang20-for-Android](https://github.com/bnsmb/clang20-for-Android)

(see [http://bnsmb.de/My_HowTos_for_Android.html#Documentation_for_the_Magisk_Module_with_clang20_and_the_NDK_r29_beta1](http://bnsmb.de/My_HowTos_for_Android.html#Documentation_for_the_Magisk_Module_with_clang20_and_the_NDK_r29_beta1) for the documentation for this Magisk Module)

---

A repository with the Magisk Module with **cmake version 3.30.4** and **ninja version 1.13.0.git** is here:

[https://github.com/bnsmb/Magisk-Module-with-cmake](https://github.com/bnsmb/Magisk-Module-with-cmake)

(A Magisk Module with **cmake version 4.x** and **ninja version 1.13.0.git** can be found in this repository)

---

The Playstore version in the Magisk Module 

**PlayStore_for_MicroG_28.3.16.21-v1.1.0.zip**

in this repo is **28.3.16.21**.

This version is quite old, but the installed Playstore is automatically updated to the latest version after the configuration of the Google account - on **29.01.2025** this is version **44.6.25.31**.

---

See 

[http://bnsmb.de/Magisk_Modules.html](http://bnsmb.de/Magisk_Modules.html)

for the documentation of the Magisk Modules in this repository

A local copy of this page is available in this repository:  [Magisk_Modules.html](./Magisk_Modules.html)
(Note that this copy may be outdated)


---
---


