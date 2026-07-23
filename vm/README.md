# VM building instructions
We describe how to use `vagrant` to build the Virtual Machine for the artifact.

## Dependencies
Make sure that you have [vagrant][] and [virtualbox][] installed to your system locally.

## Download the Vivado/Vivado HLS installer.

Unfortunately because of licensing restrictions, we cannot distribute
the VM with these tools installed. However, the tools are free, and
the installer can be downloaded [here][vivado-webpack].  To build the
VM make sure that the installer is called
`Xilinx_Unified_2022.2_1014_8888_Lin64.bin` and located in the same
directory as the `Vagrantfile`.

## Disk resizing plugin
Install the vagrant disksize plugin: `vagrant plugin install vagrant-disksize`.

## Creating the Virtual machine image
 - Run `vagrant up` and wait for this to finish.
 - Run `vagrant halt`.
 - Run `GUI=1 vagrant up`.
 - Login: the username is `vagrant` and the password is `vagrant`.
 - Run `vagrant halt`.
 - Open the VirtualBox gui and find the created VM.
 - Click Settings. Then navigate to 'Serial Ports'.
 - Disable all the serial ports.
 - Right click on entry for the VM and select, `Export to OCI`.
 - Click through and `Export`.
 - A repartitioning may be necessary to access the full 100GB of disk space.

[vagrant]: https://www.vagrantup.com/
[virtualbox]: https://www.virtualbox.org/
[vivado-webpack]: https://www.xilinx.com/member/forms/download/xef.html?filename=Xilinx_Unified_2022.2_1014_8888_Lin64.bin
