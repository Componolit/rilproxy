// Libc includes
#include <err.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

// Linux includes
#include <linux/if_ether.h>

// local includes
#include "rilproxy.h"

int
main (void)
{
    int fd;
    size_t message_len;
    char message[ETH_DATA_LEN];

    fd = open_interface (RILPROXY_INTERFACE);
    if (fd < 0)
    {
        errx (254, "Opening interface");
    }

    message_len = read (fd, &message, sizeof (message));
    printf ("Server received message of len %zd\n", message_len);
    return 0;
}
