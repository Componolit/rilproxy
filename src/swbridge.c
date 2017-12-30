#include <err.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/ether.h>
#include <linux/if_packet.h>

#include "rilproxy.h"

int
main(int argc, char **argv)
{
    int left_fd = -1;
    int right_fd = -1;

    // Check number of arguments
    if (argc != 3)
    {
        errx (1, "Insufficient arguments");
    }

    left_fd = raw_ethernet_socket (argv[1]);
    if (left_fd < 0)
    {
        err (4, "Left: create_socket(%s)", argv[1]);
    }

    right_fd = raw_ethernet_socket (argv[2]);
    if (right_fd < 0)
    {
        err (4, "Right: create_socket(%s)", argv[2]);
    }

    proxy (left_fd, right_fd);
}
