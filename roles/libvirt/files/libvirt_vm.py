#!/usr/bin/env python3

import sys
import libvirt
import time


# start VM
def start_vm(libvirt_conn, vm_name):
    try:
        dom = conn.lookupByName(vm_name)
    except libvirt.libvirtError as e:
        print(repr(e), file=sys.stderr)
        sys.exit(1)
    
    if dom.isActive():
        print("The domain {} is already activated.".format(vm_name))
        sys.exit(0)

    else:
        print("Starting domain {} ...".format(vm_name))
        try:
            dom.create()
        except libvirt.libvirtError as e:
            print(repr(e), file=sys.stderr)
            sys.exit(1)

        time.sleep(1)
        for  i_sec in range(max_waiting_time):
            if dom.isActive():
                print("Successfully started domain {}.".format(vm_name))
                sys.exit(0)
            else:
                time.sleep(1)
        print("Failed to start domain {}.".format(vm_name))
        sys.exit(1)

# stop VM
def stop_vm(libvirt_conn, vm_name):
    try:
        dom = conn.lookupByName(vm_name)
    except libvirt.libvirtError as e:
        print(repr(e), file=sys.stderr)
        sys.exit(1)

    if dom.isActive():
        print("Stopping domain {} ...".format(vm_name))
        for i_sec in range(max_waiting_time):
            if not dom.isActive():
                print("Successfully stopped domain {}.".format(vm_name))
                sys.exit(0)
            else:
                try:
                    dom.shutdown()
                    time.sleep(1)
                    # every 10 sec print waiting ...
                    if i_sec % 10 == 0:
                        print("waiting ...")
                except libvirt.libvirtError as e:
                        print(repr(e), file=sys.stderr)
                        sys.exit(1)

        # destroy vm if exceed max_waiting_time
        print("Destroying domain {} ...".format(vm_name))
        try:
            dom.destroy()
        except libvirt.libvirtError as e:
                print(repr(e), file=sys.stderr)
                sys.exit(1)
        time.sleep(1)
        if not dom.isActive():
            print("Successfully stopped domain {}.".format(vm_name))
            sys.exit(0)
        else:
            print("Can't stop domain {}.".format(vm_name))
            sys.exit(1)

    else:
        print("Domain {} already stopped.".format(vm_name))
        sys.exit(0)
            


if __name__ == '__main__':
    if len(sys.argv)==2:
        vm_name = str(sys.argv[1])
        cmd = 'start'
    elif len(sys.argv) == 3:
        vm_name = str(sys.argv[1])
        cmd = str(sys.argv[2])

    max_waiting_time = 120 # sec

    # opens up a read-write connection to the system qemu hypervisor driver,
    # checks to make sure it was successful
    conn = None
    try:
        conn = libvirt.open("qemu:///system")
    except libvirt.libvirtError as e:
        print(repr(e), file=sys.stderr)
        sys.exit(1)

    if cmd == 'start':
        start_vm(conn, vm_name)
    elif cmd == 'stop':
        stop_vm(conn, vm_name)
    else:
        print("Command not found.")

    conn.close()

sys.exit(0)

