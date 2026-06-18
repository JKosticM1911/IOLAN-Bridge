#include <unistd.h>              // read(), write(), close()
#include <string.h>              // strlen()
#include <arpa/inet.h>           // IPv6 socket structs
#include <sys/select.h>          // select()
#include <fcntl.h>               // O_NONBLOCK and O_RDWR
#include <stdint.h>
#include <stdlib.h>
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

static double yoink_reg(const char *cmd, size_t reg){

    int start = 7 + 4 * reg;

    char slice[5] = {0};

    memcpy(slice, cmd + offset, 4);

    return (double)(int16_t)strtol(hex, NULL, 16);
}

int main(void) {
    int tty, ls, cs;           // tty=serial, ls=listen socket, cs=client socket
    struct sockaddr_in6 a;     // IPv6 socket address
    socklen_t l;               // length of address struct
    char tcp[1024];            // buffers for TCP Input data
    char ser[1024];            // buffer for Serial Output Data
    char out[1024];            // buffer for TCP reply data

    // Create TCP and Serial stuff
    tty = SDK_openPort(0, O_RDWR | O_NONBLOCK);  // open serial port 
    SDK_initPort(0, tty, NULL);                  // Use DG1 Settings
    ls = socket(AF_INET6, SOCK_STREAM, 0);       // create IPv6 TCP socket

    // socket options
    int on = 1; // socket option enable flag
    setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)); // allow fast restart

    a.sin6_family = AF_INET6;  // IPv6 socket family
    a.sin6_addr = in6addr_any; // bind to all interfaces
    a.sin6_port = htons(PORT); // convert port to network byte order

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

            int n = read(cs, tcp, sizeof(tcp) - 1); // read TCP request
            if (n <= 0) break;                      // disconnect or error → exit session

            tcp[n] = 0;                             // null-terminate request string

            char *cmd = "";

            char basic[] = ":01170000000C0000000000DC" // HRS Read All command

            // Parse TCP Request
            if (strcmp(tcp, "PWM?") == 0) {
                cmd = "TODO-special";
            }else if (strcmp(tcp, "AUXPCFLOWRATE?") == 0) {
                cmd = "NOT SUPPORTED";
            else if (strcmp(tcp, "AUXPCWTEMP?") == 0) {
                cmd = "NOT SUPPORTED";
            }else if (strcmp(tcp, "IDN") == 0) {
                cmd = "HARDCODED";
            }else if (strcmp(tcp, "VFDPWR?") == 0) {
                cmd = "TODO-special";
            }else if (strcmp(tcp, "VFDACTPRESSURE?") == 0) {
                cmd = basic;
            }else if (strcmp(tcp, "VFDFLOWRATE?") == 0) {
                cmd = basic;
            }else if (strcmp(tcp, "SETTEMP?") == 0) {
                cmd = basic;
            }else if (strcmp(tcp, "TEMP?") == 0) {
                cmd = basic;
            }else if (strcmp(tcp, "FLTS1A?") == 0) {
                cmd = "TODO-Errors";
            }else {
                cmd = "INVALID CMD";
            }

            // Send chiller cmd via serial
            write(tty, cmd, strlen(cmd));

            // WAIT FOR SERIAL RESPONSE (timeout protected) --------------------
            n = 0; // reset response length
            
            if (wait_fd(tty, SERIAL_TIMEOUT_MS) > 0) { // wait for data
                n = read(tty, ser, sizeof(ser) - 1);   // read serial response
                if (n < 0) n = 0;                      // normalize error to empty response
            }

            ser[n] = 0; // null-terminate serial response

            // Parse Chiller Response ------------------------------------------
            char IDN[] = "SMC, HRSHF*, SERIAL#, Software Version 1.0";

            // VFD power percent and kW
            double vfd_per; // not supported by HRS
            double vfd_kw;  // not supported by HRS

            // discharge pressure present value
            double pres_pv = yoink_reg(ser, 2) / 100;

            // discharge Flow rate present value
            double flow_pv; // not supported by HRS 

            // discharge temp set point
            double temp_sp = yoink_reg(ser, 11) / 10; 

            // discharge temp present value
            double temp_pv = yoink_reg(ser, 0) / 10; 

            char send[32] = {0};

            // Select correct return string
            if (strcmp(tcp, "PWM?") == 0) {
                send = "TODO-special";
            }else if (strcmp(tcp, "AUXPCFLOWRATE?") == 0) {
                send = "NOT SUPPORTED";
            else if (strcmp(tcp, "AUXPCWTEMP?") == 0) {
                send = "NOT SUPPORTED";
            }else if (strcmp(tcp, "IDN") == 0) {
                send = IDN;
            }else if (strcmp(tcp, "VFDPWR?") == 0) {
                send = "TODO-special";
            }else if (strcmp(tcp, "VFDACTPRESSURE?") == 0) {
                snprintf(send, sizeof(send), "%.2f", pres_pv);
            }else if (strcmp(tcp, "VFDFLOWRATE?") == 0) {
                send = "NOT SUPPORTED by HRS";
            }else if (strcmp(tcp, "SETTEMP?") == 0) {
                snprintf(send, sizeof(send), "%.1f", temp_sp);
            }else if (strcmp(tcp, "TEMP?") == 0) {
                snprintf(send, sizeof(send), "%.1f", temp_pv);
            }else if (strcmp(tcp, "FLTS1A?") == 0) {
                send = "TODO-Errors";
            }else {
                send = "INVALID CMD";
            }

            if (n > 0) {
                write(cs, send, strlen(out));
            }
        }
        close(cs); // close TCP connection
    } // end loop
}