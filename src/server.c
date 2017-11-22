// Libc includes
#include <err.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

// local includes
#include "rilproxy.h"

int
main (void)
{
    int fd = -1;
    int rv = -1;
    message_t message;

    fd = udp_client_socket ("127.0.0.1", RILPROXY_PORT);
    if (fd < 0)
    {
        errx (254, "Opening interface");
    }

    message.length = 4;
    message.id     = MESSAGE_SETUP_ID;

    rv = write (fd, &message, sizeof (message));
    if (rv < 0)
    {
        err (1, "write");
    }

    printf ("Server: Sent startup message.\n");
    return 0;
}
