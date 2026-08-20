#include <unistd.h>              // read(), write(), close()
#include <string.h>              // strlen()
#include <arpa/inet.h>           // IPv4 socket structs
#include <sys/select.h>          // select()
#include <fcntl.h>               // O_NONBLOCK and O_RDWR
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "sdk_lib.h"             // DG1 SDK serial API

#define PORT 10001               // TCP listen port

int main(void) {
    int tty, ls, cs;           // tty=serial, ls=listen socket, cs=client socket
    struct sockaddr_in a;      // IPv4 socket address
    memset(&a, 0, sizeof(a));  // clear struct in case it had garbage

    socklen_t l;               // length of address struct
    char tcp[58] = {0};        // buffers for TCP Input data

    // Create TCP and Serial stuff
    tty = SDK_openPort(0, O_RDWR | O_NONBLOCK);  // open serial port
    SDK_initPort(0, tty, NULL);                  // Use DG1 Settings

    ls = socket(AF_INET, SOCK_STREAM, 0);       // create IPv4 TCP socket

    // socket options
    int on = 1; // socket option enable flag
    setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)); // allow fast restart

    a.sin_family = AF_INET;         // IPv4 socket family
    a.sin_port = htonl(PORT);       // bind to all interfaces
    a.sin_addr.s_addr = INADDR_ANY; // convert port to network byte order

    bind(ls, (struct sockaddr*)&a, sizeof(a)); // attach socket to port
    listen(ls, 1); // start listening (single queued client)

    // Server Loop
    while (1) {
        l = sizeof(a);                             // reset address length
        cs = accept(ls, (struct sockaddr*)&a, &l); // wait for incoming client

        // ignore failed accept attempts
        if (cs < 0) 
            continue;

        // Command loop
        while (1) {

            memset(tcp, 0, sizeof(tcp));

            int n = read(cs, tcp, sizeof(tcp) - 1); // read TCP request

            if (n <= 0) { // if nothing then exit
                close(cs);
                break;
            }

            tcp[n] = 0; // null-terminate request string

            char *response;

            response = "SMC, HRSHF*, SERIAL#, Software Version 1.1";

            // Parse TCP Request
            if (strcmp(tcp, "PWM?") == 0) { // format (+/- XX.X)
                response = "0";

            }else if (strcmp(tcp, "VFDACTPRESSURE?") == 0) { 
                // format (XXX)
                response = "40";

            }else if (strcmp(tcp, "VFDPWR?") == 0) { 
                // format (X.XXX)
                response = "100";

            }else if (strcmp(tcp, "FLTS1A?") == 0) { 
                // format (0-65535)
                response = "0";

            }else if (strcmp(tcp, "TEMP?") == 0) { 
                // format (+/- XXX.X)
                response = "16";

            }else if (strcmp(tcp, "IDN") == 0) {
                // format string
                response = "HRSHF-250";

            }else if (strcmp(tcp, "SETTEMP?") == 0) {
                // format (XXX.X))
                response = "16";

            }else if (strcmp(tcp, "AUXPCWFLOWRATE?") == 0) {
                // format (XX.X)
                response = "10";

            }else if (strcmp(tcp, "AUXPCWTEMP?") == 0) {
                // format (XX.X)
                response = "20";

            }else if (strcmp(tcp, "VFDFLOWRATE?") == 0) {
                // format (XX.X)
                response = "10";

            }else {
                response = "INVALID CMD";
            }

            // send reply
            write(cs, response, strlen(response));
        }
    }

    return 0;
}