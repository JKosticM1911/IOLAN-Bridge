#include <unistd.h>              // read(), write(), close()
#include <string.h>              // strlen()
#include <arpa/inet.h>           // IPv6 socket structs
#include <sys/select.h>          // select()
#include <fcntl.h>               // O_NONBLOCK and O_RDWR
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "sdk_lib.h"             // DG1 SDK serial API


#define PORT 10001               // TCP listen port
#define SERIAL_TIMEOUT_MS 250    // max wait for serial response

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
    int tty, ls, cs;            // tty=serial, ls=listen socket, cs=client socket
    struct sockaddr_in a;       // IPv4 socket address
    
    socklen_t l;                // length of address struct
    char tcp[128] = {0};        // buffers for TCP Input data
    char cmd[128] = {0};        // buffer for Serial commands to chiller
    char ser[128] = {0};        // buffer for Serial data from chiller
    char out[128] = {0};        // buffer for TCP reply data

    // Create TCP and Serial stuff
    tty = SDK_openPort(0, O_RDWR | O_NONBLOCK);  // open serial port
    SDK_initPort(0, tty, NULL);                  // Use DG1 Settings

    ls = socket(AF_INET, SOCK_STREAM, 0);       // create IPv4 TCP socket

    // socket options
    int on = 1; // socket option enable flag
    setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)); // allow fast restart

    a.sin_family = AF_INET;
    a.sin_port = htons(PORT);
    a.sin_addr.s_addr = INADDR_ANY;

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
            memset(ser, 0, sizeof(ser));
            memset(cmd, 0, sizeof(cmd));
            memset(out, 0, sizeof(out));

            int n = read(cs, tcp, sizeof(tcp) - 1); // read TCP request

            if (n <= 0) { // if nothing then exit
                close(cs);
                break;
            }

            tcp[n] = '\0'; // null-terminate request string

            char basic[] = ":01030000000CF0\r\n"; // HRS Read All command

            // char basic[] = ":01170000000C0000000000DC\r\n"; // HRSHF Read All command

            // Parse TCP Request, determine associated chiller command
            if (strcmp(tcp, "PWM?") == 0) {
                snprintf(cmd, sizeof(cmd), "TODO-special");
                // <- ============================================== need to test with actual HRSHF
            }else if (strcmp(tcp, "AUXPCWFLOWRATE?") == 0) {
                snprintf(cmd, sizeof(cmd), "NOT SUPPORTED");
            }else if (strcmp(tcp, "AUXPCWTEMP?") == 0) {
                snprintf(cmd, sizeof(cmd), "NOT SUPPORTED");
            }else if (strcmp(tcp, "IDN") == 0) {
                snprintf(cmd, sizeof(cmd), "HARDCODED");
            }else if (strcmp(tcp, "VFDPWR?") == 0) {
                snprintf(cmd, sizeof(cmd), "TODO-special");
                // <================================================ need to test with actual HRSHF
            }else if (strcmp(tcp, "VFDACTPRESSURE?") == 0) {
                snprintf(cmd, sizeof(cmd), basic, "%s");
            }else if (strcmp(tcp, "VFDFLOWRATE?") == 0) {
                snprintf(cmd, sizeof(cmd), basic, "%s");
            }else if (strcmp(tcp, "SETTEMP?") == 0) {
                snprintf(cmd, sizeof(cmd), basic, "%s");
            }else if (strcmp(tcp, "TEMP?") == 0) {
                snprintf(cmd, sizeof(cmd), basic, "%s");
            }else if (strcmp(tcp, "FLTS1A?") == 0) {
                snprintf(cmd, sizeof(cmd), "TODO-Errors");
                // <=============================================== need to test with actual HRSHF
            }else {
                snprintf(cmd, sizeof(cmd), "INVALID CMD");
            }

            if (cmd[0] == ':') { // only if a valid chiller command is selected
                write(tty, cmd, strlen(cmd));

                // Serial Read -----------------------------------------------------
                n = 0;
                int wait = SERIAL_TIMEOUT_MS;           // long wait for the first byte
                while (n < (int)sizeof(ser) - 1 && wait_fd(tty, wait) > 0) {
                    int r = read(tty, ser + n, sizeof(ser) - 1 - n);
                if (r <= 0) break;
                    n += r;
                if (ser[n - 1] == '\n') break;          // complete frame received
                    wait = 50;                          // then only allow short gaps
                }

                ser[n] = '\0'; // null-terminate serial response

            }

            // Parse Chiller Response ------------------------------------------

            double pres_pv = -1;
            double temp_sp = -1;
            double temp_pv = -1;

                        
            // hardcoded IDN string; needed even if serial coms doesn't happen
            char IDN[] = "HRSHF-250\0";

            
            if (n > 56){ // if reply is long enough
                
                // VFD power percent and kW
                //double vfd_per; // not supported by HRS (TODO)
                //double vfd_kw;  // not supported by HRS (TODO)

                // discharge pressure present value
                pres_pv = yoink_reg(ser, 3) / 100;

                // discharge Flow rate present value
                //double flow_pv; // <================================ can't add until I have actual HRSHF

                // discharge temp set point
                temp_sp = yoink_reg(ser, 12) / 10;

                // discharge temp present value
                temp_pv = yoink_reg(ser, 1) / 10;
            }

            if (strcmp(tcp, "PWM?") == 0) {
                snprintf(out, sizeof(out), "TODO-special"); // can't test without actual HRSHF
            }else if (strcmp(tcp, "AUXPCWFLOWRATE?") == 0) {
                snprintf(out, sizeof(out), "NOT SUPPORTED");
            }else if (strcmp(tcp, "AUXPCWTEMP?") == 0) {
                snprintf(out, sizeof(out), "NOT SUPPORTED");
            }else if (strcmp(tcp, "IDN") == 0) {
                snprintf(out, sizeof(out), "%s", IDN);
            }else if (strcmp(tcp, "VFDPWR?") == 0) {
                snprintf(out, sizeof(out), "TODO-special"); // can't test without actual HRSHF
            }else if (strcmp(tcp, "VFDACTPRESSURE?") == 0) {
                snprintf(out, sizeof(out), "%.2f", pres_pv);
                //snprintf(out, sizeof(out), "%s", ser);
            }else if (strcmp(tcp, "VFDFLOWRATE?") == 0) {
                snprintf(out, sizeof(out), "NOT SUPPORTED by HRS"); // <===== can't verify without actual HRSHF
            }else if (strcmp(tcp, "SETTEMP?") == 0) {
                snprintf(out, sizeof(out), "%.1f", temp_sp);
                //snprintf(out, sizeof(out), "%s", ser);
            }else if (strcmp(tcp, "TEMP?") == 0) {
                snprintf(out, sizeof(out), "%.1f", temp_pv);
                //snprintf(out, sizeof(out), "%s", ser);
            }else if (strcmp(tcp, "FLTS1A?") == 0) {
                snprintf(out, sizeof(out), "TODO-Errors"); // can't test without actual HRSHF
            }else {
                snprintf(out, sizeof(out), "INVALID CMD");
            }
            // send reply

            write(cs, out, strlen(out));
        }
    }

    // this should never execute, if it is does something went wrong
    char exit[] = "main has exited";
    write(cs, exit, strlen(exit));

    return 0;
}