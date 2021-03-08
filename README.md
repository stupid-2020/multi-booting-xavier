# Multi-booting for the Jetson AGX Xavier with NVMe SSD
[![](https://badgen.net/badge/platform/jetson-xavier)](https://developer.nvidia.com/embedded/jetson-agx-xavier-developer-kit)

This project provides tools to add boot entry to `extlinux.conf` for a partition with JetPack installed.  This allows multi-booting via the [serial console](https://elinux.org/Jetson/AGX_Xavier_Tegra_Combined_UART).

# Overview
## Why NVMe SSD
* SSD provides much faster IO speed
```
/dev/mmcblk0p1 (internal EMMC): Bufferd reads = 292 MB/s
/dev/mmcblk1p1 (Sandisk Ultra U1 SD card): Bufferd reads = 81 MB/s
/dev/nvme0n1p1 (Kingston NVME M.2): Bufferd reads = 1316 MB/s
/dev/nvme0n1p1 (970 EVO Plus M.2): Bufferd reads = 1670 MB/s
```
* SSD has larger storage capacity (>1TB) than eMMC (32GB)
* There is no way to upgrade/replace eMMC (although NVIDIA claims it can last up to [5 years](https://developer.nvidia.com/embedded/faq#jetson-lifetime))

## Why Multi-booting
* Try different JetPack versions without changing SSD or reflash.  (For example, `jetpack_44` on `/dev/nvme0n1p1`, `jetpack-4.3` on `/dev/nvme0n1p2`)
* Run different projects with same JetPack version without changing SSD or reflash (Say, `jp44_human_pose` on `/dev/nvme0n1p1`, `jp44_jetbot` on `/dev/nvme0n1p2`)
* Replace a SSD without reflash (Maybe `john_jetpack_44` on `/dev/nvme0n1p1`, `jane_jetpack_45` on `/dev/nvme0n1p1`)
* Just for fun

## What JetPack Versions are Supported:
The project has been tested with the following JetPack versions:
* JetPack 4.5.1
* JetPack 4.4.1
* JetPack 4.3
* JetPack 4.2.3

<br />

# Preparation
This section will help you to prepare the bootable partition(s) with desired JetPack version.  We assume that you know how to format disk with GPT partitioning scheme and create/delete partition(s) using [GNOME Disk Utility](#reference)

## How to Flash
### Method 1: Use [SDK Manager GUI](https://developer.nvidia.com/nvidia-sdk-manager)
1. Connect Jetson Xavier (in [Recovery Mode](#force-recovery-mode-when-power-off)) to the host with SDK Manager installed
2. Select target operating system (JetPack version)
3. Complete the Ubuntu system configuration

### Method 2: Use *flash.s<span>h</span>*
This method is more precise but only available when Jetson OS image has been created before (The path varies from version to version.  By default it should be under user's home folder).  For example, to flash `JetPack 4.4.1`:
```bash
$ cd ~/nvidia/nvidia_sdk/
$ cd JetPack_4.4.1_Linux_JETSON_AGX_XAVIER/Linux_for_Tegra
$ sudo ./flash.sh jetson-xavier mmcblk0p1
```
After flashing, complete the Ubuntu system configuration.

## Clone *rootfs* to the target partition
My method here is simple but not a beautiful/clean cloning.  You could find other way from Internet or use it as-is.  Now, Jetson Xavier should be booted with JetPack version installed in previous step from eMMC.  If we would like to clone *rootfs* to `/dev/nvme0n1p1`, please follow the steps below:
```bash
$ mkdir /tmp/rootfs
$ sudo mount /dev/nvme0n1p1 /tmp/rootfs
$ cd /
$ sudo cp -ax ./ /tmp/rootfs
```

## Prepare a Backup entry on eMMC
This allow you to boot Jetson Xavier even there is no SSD installed (or something wrong with the SSD, point to wrong partition or incorrect boot entry).  We should install the latest JetPack version (to support bootin older version).  Follows section [How to Flash](#how-to-flash) to flash `JetPack 4.5.1`

After that, `JetPack 4.5.1` should be installed on eMMC and `JetPack 4.4.1` on `/dev/nvme0n1p1`.

<br />

# Add Boot Entry
To continue the previous example, to enable multi-booting (`JetPack 4.5.1` on eMMC and `JetPack 4.4.1` on `/dev/nvme0n1p1`), we could run the following steps:
```bash
$ sudo -i
# /path/to/multi-booting-xavier/add_jetpack.sh /dev/nvme0n1p1 human_pose
```
Once completed successfully and reboot, you could find something like the following via the serial console:
```
[0005.815] I> L4T boot options
[0005.815] I> [1]: "primary kernel"
[0005.815] I> [2]: "JetPack 4.4 human_pose"
[0005.816] I> Enter choice:
```
At that point, you can choose the kernel before expiration of the `TIMEOUT` period (3 seconds).

## A Complete Example
Let's say the NVMe SSD has four partitions and are assigned as the following (You can check the final [multi-booting configuration](extlinux.conf.sample)):

Partition       | JetPack Version | Project
--------------- | --------------- | -----------
/dev/nvme0n1p1  | JetPack 4.5.1   | human_pose
/dev/nvme0n1p2  | JetPack 4.4.1   | jp44_jetbot
/dev/nvme0n1p3  | JetPack 4.3     | DeepSpeech
/dev/nvme0n1p4  | JetPack 4.2.3   | smart_detector

To enable multi-booting with different JetPack versions like that.  Just follow the steps below:
1. Flash `JetPack 4.2.3` to eMMC
2. Clone *rootfs* to `/dev/nvme0n1p4`
3. Flash `JetPack 4.3` to eMMC
4. Clone *rootfs* to `/dev/nvme0n1p3`
5. Flash `JetPack 4.4.1` to eMMC
6. Clone *rootfs* to `/dev/nvme0n1p2`
7. Flash `JetPack 4.5.1` to eMMC
8. Clone *rootfs* to `/dev/nvme0n1p1`
9. Run `add_jetpack.sh /dev/nvme0n1p1 human_pose`
10. Run `add_jetpack.sh /dev/nvme0n1p2 jp44_jetbot`
11. Run `add_jetpack.sh /dev/nvme0n1p3 DeepSpeech`
12. Run `add_jetpack.sh /dev/nvme0n1p4 smart_detector`
13. Done

When the system boots, you could find something like the following via the serial console:
```
[0005.815] I> L4T boot options
[0005.815] I> [1]: "primary kernel"
[0005.815] I> [2]: "JetPack 4.5 human_pose"
[0005.815] I> [2]: "JetPack 4.4 jp44_jetbot"
[0005.815] I> [2]: "JetPack 4.3 DeepSpeech"
[0005.816] I> [2]: "JetPack 4.2 smart_detector"
[0005.816] I> Enter choice:
```
You can select the kernel everytime or you could update the default by [editing extlinux.conf](#edit-extlinuxconf)

<br />

# Notes
Maybe you will find that it is not that useful as you need to flash the eMMC and clone the *rootfs* everytime for a new partition.

To avoid the redundant work, it is recommended to backup the partition(s) you need.  You can use [`dd`](https://elinux.org/Jetson/AGX_Xavier_Alternative_II_For_Cloning), [`cpio`](https://forums.developer.nvidia.com/t/xavier-cloning/65159/5) or a spare storage to keep the partition(s).

Next time, you can simply restore/clone the backup to the new partition, run the command `add_jetpack.sh` on Jetson Xavier and done.

<br />

# Miscellaneous
## Force Recovery Mode (when Power Off)
1. Press and hold down the Force Recovery button
2. Press and hold down the Power button
3. Release both buttons

## Force Recovery Mode (when Power On)
1. Press and hold down the Force Recovery button
2. Press and hold down the Reset button
3. Release both buttons

## Edit `extlinux.conf`
**Be Cautious**.  Invalid `extlinux.conf` will cause the system to become unbootable.  Backup before you edit, think twice before you act, double check before you save.

To ensure we are editing the correct `extlinux.conf`, do the following:
```bash
$ mkdir /tmp/emmc
$ sudo mount /dev/mmcblk0p1 /tmp/emmc
$ sudo vi /tmp/emmc/boot/extlinux/extlinux.conf
```

<br />

# Reference
* [NVIDIA Jetson Xavier - CBoot](https://docs.nvidia.com/jetson/archives/l4t-archived/l4t-3231/index.html#page/Tegra%2520Linux%2520Driver%2520Package%2520Development%2520Guide%2Fbootflow_jetson_xavier.html%23wwpID0E0HB0HA)
* [Disk Utility](https://linuxhint.com/gnome_disk_utility/)
* [How to Boot from NVMe SSD](https://forums.developer.nvidia.com/t/how-to-boot-from-nvme-ssd/65147/17)
* [NVIDIA Jetson Xavier - Using the serial console](https://developer.ridgerun.com/wiki/index.php?title=Xavier%2FIn_Board%2FGetting_in_Board%2FSerial_Console)
* [Quad-RS232 Driver for Windows](https://ftdichip.com/wp-content/uploads/2021/02/CDM21228_Setup.zip)
