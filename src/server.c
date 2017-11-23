// Libc includes
#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// local includes
#include "rilproxy.h"

int
main (int argc, char **argv)
{
    int fd = -1;
    int rv = -1;
    char *remote_server, *local_socket;
    unsigned short remote_port;

    if (argc < 4) errx (1, "Insufficient arguments (%s <local_socket> <remote_server> <remote_port>)", argv[0]);

    local_socket = argv[1];
    remote_server = argv[2];
    remote_port = atoi(argv[3]);

    printf ("Connecting %s to %s:%d\n", local_socket, remote_server, remote_port);

    // Open UDP socket to client proxy
    fd = udp_client_socket (remote_server, remote_port);
    if (fd < 0) errx (254, "Opening interface");

    rv = send_control_message (fd, MESSAGE_SETUP_ID);
    if (rv < 0) errx (253, "Sending control message");

    printf ("Server: Sent startup message.\n");
    return 0;
}
