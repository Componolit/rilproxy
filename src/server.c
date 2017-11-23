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
    int remote = -1;
    int local = -1;
    int rv = -1;
    char *remote_server, *local_path;
    unsigned short remote_port;

    if (argc < 4) errx (1, "Insufficient arguments (%s <local_socket_path> <remote_server> <remote_port>)", argv[0]);

    local_path = argv[1];
    remote_server = argv[2];
    remote_port = atoi(argv[3]);

    printf ("Connecting %s to %s:%d\n", local_path, remote_server, remote_port);

    // Open UDP socket to client proxy
    remote = udp_client_socket (remote_server, remote_port);
    if (remote < 0) errx (254, "Opening remote socket");
    printf ("Server: UDP socket created.\n");

    // Create RILd socket
    local = unix_server_socket (local_path, "radio");
    if (local < 0) errx (253, "Opening local socket");
    printf ("Server: Unix domain socket created.\n");

    // Connected, send startup message
    rv = send_control_message (remote, MESSAGE_SETUP_ID);
    if (rv < 0) errx (253, "Sending control message");
    printf ("Server: Sent startup message.\n");

    proxy (local, remote);
    return 0;
}
