#include <unistd.h>              // read(), write(), close()
#include <string.h>              // strlen()
#include <arpa/inet.h>           // IPv6 socket structs
#include <sys/select.h>          // select()
#include <fcntl.h>               // O_NONBLOCK and O_RDWR
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "sdk_lib.h"             // DG1 SDK serial API

#define PORT 10010                 // TCP listen port
#define SERIAL_TIMEOUT_MS 15000   // max wait for serial response

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

    int start = 7 + 4 * (reg - 1);

    char slice[5] = {0};

    memcpy(slice, cmd + start, 4);

    return (double)(int16_t)strtol(slice, NULL, 16);
}

int main(void) {
    int tty, ls, cs;           // tty=serial, ls=listen socket, cs=client socket
    struct sockaddr_in6 a;     // IPv6 socket address
    socklen_t l;               // length of address struct
    char tcp[60] = {0};        // buffers for TCP Input data
    char ser[60] = {0};        // buffer for Serial Output Data
    char out[60] = {0};        // buffer for TCP reply data

    // Server Loop
    while (1) {

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

        l = sizeof(a);                             // reset address length
        cs = accept(ls, (struct sockaddr*)&a, &l); // wait for incoming client

        // ignore failed accept attempts
        if (cs < 0) 
            continue;

        // Command loop
        while (1) {

            memset(tcp, 0, sizeof(tcp));
            memset(ser, 0, sizeof(ser));
            memset(out, 0, sizeof(out));

            int n = read(cs, tcp, sizeof(tcp) - 1); // read TCP request

            if (n <= 0) { // if nothing then exit
                close(cs);
                break;
            }

            tcp[n] = 0; // null-terminate request string

            char *cmd = "";

            char basic[] = ":01030000000CF0\r\n"; // HRS Read All command

            // Parse TCP Request
            if (strcmp(tcp, "PWM?") == 0) {
                cmd = "TODO-special";
            }else if (strcmp(tcp, "AUXPCFLOWRATE?") == 0) {
                cmd = "NOT SUPPORTED";
            }else if (strcmp(tcp, "AUXPCWTEMP?") == 0) {
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

            // out chiller cmd via serial
            if (cmd[0] == ':') { // make sure it's a valid chiller cmd

                char flush[256]; // flush buffer of any stray bytes
                while (read(tty, flush, sizeof(flush)) > 0){
                    ;
                }
                usleep(15000);
                write(tty, cmd, strlen(cmd));
            }

            // WAIT FOR SERIAL RESPONSE (timeout protected) --------------------
            n = 0; // reset response length
                
            if (wait_fd(tty, SERIAL_TIMEOUT_MS) > 0) { // wait for data
                n = read(tty, ser, sizeof(ser) - 1);   // read serial response
               if (n < 0) n = 0;                       // normalize error to empty response
            }

            ser[n] = 0; // null-terminate serial response

            // Parse Chiller Response ------------------------------------------

            double pres_pv = -1;
            double temp_sp = -1;
            double temp_pv = -1;

                        
            // hardcoded IDN string; needed even if serial coms doesn't happen
            char IDN[] = "SMC, HRSHF*, SERIAL#, Software Version 1.1";

            
            if (n > 56){ // if reply is long enough
                
                // VFD power percent and kW
                //double vfd_per; // not supported by HRS (TODO)
                //double vfd_kw;  // not supported by HRS (TODO)

                // discharge pressure present value
                pres_pv = yoink_reg(ser, 3) / 100;

                // discharge Flow rate present value
                //double flow_pv; // not supported by HRS  

                // discharge temp set point
                temp_sp = yoink_reg(ser, 12) / 10;

                // discharge temp present value
                temp_pv = yoink_reg(ser, 1) / 10;


                if (strcmp(tcp, "PWM?") == 0) {
                    snprintf(out, sizeof(out), "TODO-special");
                }else if (strcmp(tcp, "AUXPCFLOWRATE?") == 0) {
                    snprintf(out, sizeof(out), "NOT SUPPORTED");
                }else if (strcmp(tcp, "AUXPCWTEMP?") == 0) {
                    snprintf(out, sizeof(out), "NOT SUPPORTED");
                }else if (strcmp(tcp, "IDN") == 0) {
                    snprintf(out, sizeof(out), "%s", IDN);
                }else if (strcmp(tcp, "VFDPWR?") == 0) {
                    snprintf(out, sizeof(out), "TODO-special");
                }else if (strcmp(tcp, "VFDACTPRESSURE?") == 0) {
                    snprintf(out, sizeof(out), "%.2f", pres_pv);
                }else if (strcmp(tcp, "VFDFLOWRATE?") == 0) {
                    snprintf(out, sizeof(out), "NOT SUPPORTED by HRS");
                }else if (strcmp(tcp, "SETTEMP?") == 0) {
                    snprintf(out, sizeof(out), "%.1f", temp_sp);
                }else if (strcmp(tcp, "TEMP?") == 0) {
                    snprintf(out, sizeof(out), "%.1f", temp_pv);
                }else if (strcmp(tcp, "FLTS1A?") == 0) {
                    snprintf(out, sizeof(out), "TODO-Errors");
                }else {
                    snprintf(out, sizeof(out), "INVALID CMD");
                }

                // send reply
                write(cs, out, strlen(out));

            }else{
                write(cs, ser, strlen(ser));
            }
        }
    }

    // this should never execute, if it is does something went wrong
    char exit[] = "main has exited";
    write(cs, exit, strlen(exit));

    return 0;
}