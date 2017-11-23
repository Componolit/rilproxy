// Libc includes
#include <err.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>

// Linux includes
#include <linux/if_ether.h>

// local includes
#include "rilproxy.h"

int
main (int argc, char **argv)
{
    int rv = -1;
    int remote = -1;
    int local = -1;
    char *local_path;
    unsigned short local_port;

    if (argc < 3) errx (1, "Insufficient arguments (%s <local_socket_path> <listening port>)", argv[0]);

    local_path = argv[1];
    local_port = atoi(argv[2]);

    // Open listening UDP socket
    remote = udp_server_socket (local_port);
    if (remote < 0) errx (254, "Opening interface");

    // Wait for setup message
    wait_control_message (remote, MESSAGE_SETUP_ID);

    // Drop privileges to 'radio'
    rv = setuid (get_uid ("radio"));
    if (rv < 0)
    {
        send_control_message (remote, MESSAGE_TEARDOWN_ID);
        err (253, "Dropping user to 'radio'");
    }

    // Open unix domain socket
    local = unix_server_socket (local_path);
    if (local < 0)
    {
        send_control_message (remote, MESSAGE_TEARDOWN_ID);
        errx (252, "Opening local unix domain socket");
    }

    proxy (local, remote);
    return 0;
}
