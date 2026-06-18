#include <unistd.h>              // read(), write(), close()
#include <string.h>              // strlen()
#include <arpa/inet.h>           // IPv6 socket structs
#include <sys/select.h>          // select()
#include <fcntl.h>               // O_NONBLOCK and O_RDWR

#include "sdk_lib.h"             // DG1 SDK serial API

#define PORT 10010               // TCP listen port
#define SERIAL_TIMEOUT_MS 1000   // max wait for serial response

// Helper: wait until fd becomes readable or timeout expires -------------------
static int wait_fd(int fd, int ms) {
    fd_set fds;        // fd set for select()
    struct timeval tv; // timeout structure

    FD_ZERO(&fds);     // clear set
    FD_SET(fd, &fds);  // add fd to monitor

    tv.tv_sec  = ms / 1000;          // seconds part of timeout
    tv.tv_usec = (ms % 1000) * 1000; // microseconds part

    return select(fd + 1, &fds, NULL, NULL, &tv); // wait for readability
}

int main(void) {
    int tty, ls, cs;           // tty=serial, ls=listen socket, cs=client socket
    struct sockaddr_in6 a;     // IPv6 socket address
    socklen_t l;               // length of address struct
    char tcp[1024];            // buffers for TCP Input data
    char ser[1024];            // buffer for Serial Output Data
    char out[1024];            // buffer for TCP reply data

    // SERIAL PORT INITIALIZATION ----------------------------------------------
    tty = SDK_openPort(0, O_RDWR | O_NONBLOCK); // open serial port 0 (non-blocking)
    SDK_initPort(0, tty, NULL);                 // apply DG1 configured line settings

    // TCP SERVER INITIALIZATION -----------------------------------------------
    ls = socket(AF_INET6, SOCK_STREAM, 0); // create IPv6 TCP socket

    int on = 1;                            // socket option enable flag
    setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)); // allow fast restart

    a.sin6_family = AF_INET6;  // IPv6 socket family
    a.sin6_addr = in6addr_any; // bind to all interfaces
    a.sin6_port = htons(PORT); // convert port to network byte order

    bind(ls, (struct sockaddr*)&a, sizeof(a)); // attach socket to port
    listen(ls, 1); // start listening (single queued client)

    // MAIN SERVER LOOP (runs forever) -----------------------------------------
    while (1) {
        l = sizeof(a);                             // reset address length
        cs = accept(ls, (struct sockaddr*)&a, &l); // wait for incoming client

        if (cs < 0)                                // ignore failed accept attempts
            continue;

        // CLIENT SESSION LOOP (request/response cycle) ------------------------
        while (1) {

            int n = read(cs, tcp, sizeof(tcp) - 1); // read TCP request
            if (n <= 0) break;                      // disconnect or error → exit session

            tcp[n] = 0;                             // null-terminate request string

            // SEND REQUEST TO SERIAL DEVICE -----------------------------------
            char Chiller_CMD[] = ":010400000004F7";
            write(tty, Chiller_CMD, strlen(Chiller_CMD)); // send chiller command

            // WAIT FOR SERIAL RESPONSE (timeout protected) --------------------
            n = 0; // reset response length
            
            if (wait_fd(tty, SERIAL_TIMEOUT_MS) > 0) { // wait until serial data arrives
                n = read(tty, ser, sizeof(ser) - 1);   // read serial response
                if (n < 0) n = 0;                      // normalize error to empty response
            }

            ser[n] = 0; // null-terminate serial response

            // Parse Chiller command:
            char vfd_kws[10]; // VFD power in kw
            char vfd_per[10]; // VFD power in percentage
            char pres_pv[10]; // discharge pressure present value
            char flow_pv[10]; // discharge Flow rate present value
            char temp_sp[10]; // discharge temp set point
            char temp_pv[10]; // discharge temp present value

            char *out = "";

            if (strcmp(tcp, "PWM?") == 0) {
                out = "1";
            }else if (strcmp(tcp, "AUXPCFLOWRATE?") == 0) {
                out = "2";
            }else if (strcmp(tcp, "IDN") == 0) {
                out = "3";
            }else if (strcmp(tcp, "VFDPWR?") == 0) {
                out = "4";
            }else if (strcmp(tcp, "VFDACTPRESSURE?") == 0) {
                out = "5";
            }else if (strcmp(tcp, "SETTEMP?") == 0) {
                out = "6";
            }else if (strcmp(tcp, "TEMP?") == 0) {
                out = "7";
            }else if (strcmp(tcp, "FLTS1A?") == 0) {
                out = "8";
            }else {
                out = "UNKNOWN";
            }

            if (n > 0) {
                write(cs, out, strlen(out));
            }
        }
        close(cs); // close TCP connection
    } // end loop
}