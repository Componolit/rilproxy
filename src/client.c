// Libc includes
#include <err.h>
#include <stdio.h>
#include <fcntl.h>

// Linux includes
#include <linux/if_ether.h>

// local includes
#include "rilproxy.h"

int
main (void)
{
    int fd;
    char buffer[1500];
    ssize_t msize;
    message_t *message;

    fd = udp_server_socket (RILPROXY_PORT);
    if (fd < 0)
    {
        errx (254, "Opening interface");
    }

    msize = read (fd, &buffer, sizeof (buffer));
    if (msize < 0)
    {
        err (1, "read");
    }

    message = (message_t *)&buffer;
    if (message->length == 4 && message->id == MESSAGE_SETUP_ID)
    {
        printf ("Got startup message");
    } else
    {
        printf ("Got unknow message (len=%d, id=%x)", message->length, message->id);
    }

    printf ("Client\n");
    return 0;
}
