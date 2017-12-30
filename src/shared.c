// Libc includes
#include <err.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <pwd.h>
#include <unistd.h>
#include <arpa/inet.h> // for htons
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <net/if.h>
#include <linux/if_packet.h>
#include <netinet/ether.h>

#include "rilproxy.h"

int
udp_socket (const char *host, unsigned short port)
{
    struct sockaddr_in local_addr;
    struct sockaddr_in remote_addr;
	int fd, rv;

	fd = socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (fd < 0) err (1, "socket");

    int enable = 1;
    rv = setsockopt (fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
    if (rv < 0) warn ("setsockopt(SO_REUSEADDR)");
	
	memset (&local_addr, 0, sizeof (local_addr));
	
	local_addr.sin_family      = AF_INET;
	local_addr.sin_port        = htons(port);
	local_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	
	rv = bind (fd, (struct sockaddr*)&local_addr, sizeof(local_addr));
	if (rv < 0) err (2, "udp_server_socket.bind to %d", port);

    remote_addr.sin_family = AF_INET;
    remote_addr.sin_port   = htons(port);
    remote_addr.sin_addr.s_addr = inet_addr(host);

    rv = connect (fd, (struct sockaddr *)&remote_addr, sizeof(remote_addr));
    if (rv < 0) err (2, "connect");

	return fd;
}

int
unix_client_socket (const char *socket_path)
{
    int rv = -1;
    int fd = -1;
    struct sockaddr_un addr;

    fd = socket (AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) err (1, "socket");

    addr.sun_family = AF_UNIX;
    strncpy (addr.sun_path, socket_path, sizeof (addr.sun_path));

    rv = connect (fd, (struct sockaddr *)&addr, sizeof (struct sockaddr_un));
    if (rv < 0)
    {
        close (fd);
        err (2, "unix_client_socket.connect to %s", socket_path);
    }

    fprintf (stderr, "Connected to %s\n", socket_path);
    return fd;
}

int
unix_server_socket (const char *socket_path, const char *user)
{
    int rv = -1;
    int fd = -1;
    int msgfd = -1;
    struct sockaddr_un addr;

    fd = socket (AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) err (1, "socket");

    addr.sun_family = AF_UNIX;
    strncpy (addr.sun_path, socket_path, sizeof (addr.sun_path));

    rv = bind (fd, (struct sockaddr *)&addr, sizeof (struct sockaddr_un));
    if (rv < 0) err (2, "unix_server_socket.bind to %s", socket_path);

    // Change user
    rv = chown (socket_path, get_uid (user), -1);
    if (rv < 0) err (3, "unix_server_socket.chown of %s", socket_path);

    // Change mode
    rv = chmod (socket_path, 0666);
    if (rv < 0) err (4, "unix_server_socket.chmod of %s", socket_path);

    rv = listen (fd, 1);
    if (rv < 0) err (5, "unix_server_socket.listen for %s", socket_path);

    msgfd = accept (fd, NULL, NULL);
    if (msgfd < 0) err (5, "unix_server_socket.accept to %s", socket_path);

    rv = close (fd);
    if (rv < 0) err (6, "unix_server_socket.close for %s", socket_path);

    rv = unlink (socket_path);
    if (rv < 0) err (7, "unix_server_socket.unlink for %s", socket_path);

    return (msgfd);
}

int
raw_ethernet_socket(const char *interface_name)
{
    int fd = -1;
    int rv = -1;
    int sockopt;
    struct sockaddr_ll bindaddr;
    struct ifreq if_idx;

    // Create socket (note: need root or CAP_NET_RAW)
    fd = socket (AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (fd < 0)
    {
        return -1;
    }

    // Make socket reusable
    sockopt = 1;
    rv = setsockopt (fd, SOL_SOCKET, SO_REUSEADDR, &sockopt, sizeof (sockopt));
    if (rv < 0)
    {
        return -1;
    }

    // Get interface index
    bzero (&if_idx, sizeof (if_idx));
    strncpy (if_idx.ifr_name, interface_name, IFNAMSIZ - 1);
    rv = ioctl (fd, SIOCGIFINDEX, &if_idx);
    if (rv < 0)
    {
        return -1;
    }

    // Bind socket to interface
    rv = setsockopt (fd, SOL_SOCKET, SO_BINDTODEVICE, (void *)&if_idx, sizeof(if_idx));
    if (rv < 0)
    {
        return -1;
    }

    // Bind to interfaces for sending
    bzero (&bindaddr, sizeof(bindaddr));
    bindaddr.sll_family   = AF_PACKET;
    bindaddr.sll_protocol = htons(ETH_P_ALL);
    bindaddr.sll_ifindex  = if_idx.ifr_ifindex;

    rv = bind (fd, (struct sockaddr *)&bindaddr, sizeof (bindaddr));
    if (rv < 0)
    {
        return -1;
    }
    return fd;
}

struct passwd *
get_user (const char *username)
{
    struct passwd *user;

    user = getpwnam (username);
    if (user == NULL)
    {
        warn ("getpwnam(%s)", username);
        return NULL;
    }

    return user;
}

int
get_uid (const char *username)
{
    struct passwd *user = get_user (username);
    return user->pw_uid;
}

int
get_gid (const char *username)
{
    struct passwd *user = get_user (username);
    return user->pw_gid;
}

int
send_control_message (int fd, uint32_t message_type)
{
    int rv = -1;
    message_t message;

    message.length = htonl (4);
    message.id     = message_type;

    rv = write (fd, &message, sizeof (message));
    if (rv < 0)
    {
        warn ("send_control_message.write message %u", message_type);
        return -1;
    }

    return 0;
}

int
socket_copy (int source_fd, int dest_fd, const char *local, const char *remote)
{
    ssize_t i;
    ssize_t bytes_written = -1;
    ssize_t bytes_read = -1;
    char buffer[RILPROXY_BUFFER_SIZE];
    char hexdump_buffer[3*sizeof(buffer)+1];

    bytes_read = read (source_fd, &buffer, sizeof (buffer));
    if (bytes_read < 0)
    {
        warn ("socket_copy: error reading source socket");
        return -SOCKET_COPY_READ_ERROR;
    }

    if (bytes_read == 0)
    {
        warn ("socket_copy: reading socket closed");
        return -SOCKET_COPY_READ_CLOSED;
    }

    bytes_written = write (dest_fd, &buffer, bytes_read);
    if (bytes_written < 0)
    {
        warn ("socket_copy: error writing destination socket");
        return -SOCKET_COPY_WRITE_ERROR;
    }

    if (bytes_written < bytes_read)
    {
        warn ("socket_copy: read %zd bytes, wrote %zd bytes", bytes_read, bytes_written);
        return 0;
    }

    warnx ("[%s -> %s]: read %zd, wrote %zd bytes", local, remote, bytes_read, bytes_written);

    // Prepare hexdump
    bzero (hexdump_buffer, sizeof (hexdump_buffer));
    for (i = 0; i < bytes_read; i++)
    {
        sprintf (hexdump_buffer + 3*i, "%02x ", 0xff & buffer[i]);
    }
    warnx ("[%s -> %s]: %s", local, remote, hexdump_buffer);

    return 0;
}

void
proxy (int local_fd, int remote_fd)
{
    int rv = -1;
    fd_set fds;

    for (;;)
    {
        FD_ZERO (&fds);
        FD_SET (local_fd, &fds);
        FD_SET (remote_fd, &fds);

        rv = select (MAX(local_fd, remote_fd) + 1, &fds, NULL, NULL, NULL);
        if (rv < 0)
        {
            warn ("select failed");
            continue;
        }

        if (FD_ISSET (local_fd, &fds))
        {
            socket_copy (local_fd, remote_fd, "local", "remote");
        }

        if (FD_ISSET (remote_fd, &fds))
        {
            socket_copy (remote_fd, local_fd, "remote", "local");
        }
    }
}

void
wait_control_message (int fd, uint32_t message_type)
{
    ssize_t msize;
    char buffer[1500];
    message_t *message;

    for (;;)
    {
        msize = read (fd, &buffer, sizeof (buffer));
        if (msize < 0)
        {
            err (1, "read");
        }

        message = (message_t *)&buffer;
        uint32_t len = ntohl (message->length);
        if (len == 4 && message->id == message_type)
        {
            return;
        }

        printf ("Got unknown message (len=%d, id=%x)\n", len, message->id);
    }
}
