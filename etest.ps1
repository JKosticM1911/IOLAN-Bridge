#===============================================================================
# Program:  test.ps1 (IOLAN-Bridge testing script)
# Author:   Paul Kostic
# Date:     6/13/2026
#===============================================================================
# This program assumes that the IOLAN has been configured per the README
#===============================================================================

# $Inteface_list = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

class test {

    # $IPV6 = "fe80::280:d4ff:fe32:80a8"
    # $Eth = "enp0s31f6"

    # TCP Socket Object
    [System.Net.Sockets.Socket]$TCP

    # TCP EndPoint Object
    [System.Net.IPEndPoint]$TCPEND

    #buffers
    $rxbuff
    $txbuff

    # Constructor ==============================================================
    test() {
        # Set TCP Socket Data
        $this.TCP = [System.Net.Sockets.Socket]::new(
            [System.Net.Sockets.AddressFamily]::InterNetwork,
            [System.Net.Sockets.SocketType]::Stream,
            [System.Net.Sockets.ProtocolType]::Tcp
        )

        # Set TCP Endpoint Data
        $ip = [System.Net.IPAddress]::Parse("192.168.168.35")

        $this.TCPEND = [System.Net.IPEndPoint]::new(
            $ip,                # 
            10001               # port used
        )

        #create buffers
        $this.rxbuff = New-Object byte[] 1024
        $this.txbuff = New-Object byte[] 1024
    }

    [void]des() {
        $this.TCP.Close()
    }

    # Main Loop ================================================================

    [void]main() {

        $good_tcp = $this.connect_tcp();

        if ($good_tcp -lt 0)  {
            return
        }

        while ($true) { # Main loop
            $tx = Read-Host "TCP TX"
            switch ($tx) {
                "exit"   {return}
                'h'       {$this.help()}
                "clear"   {Clear-Host}
                default {

                    if ($good_tcp -gt 0){
                        $this.send_tcp($tx)
                    }

                    if ($good_tcp -gt 0) {
                        $this.recv_tcp()
                    }
                }
            }
        }
    }

    [void]help() {
        Write-Host "General Commands:"
        Write-Host "exit                Exit the program"
        Write-Host "clear               Clear the console`n"

        Write-Host "Chiller Commands:"
        Write-Host "PWM?                Read current load in percent of maximum cooling capacity (25kW) based on compressor usage"
        Write-Host "AUXPCWFLOWRATE?     Read current measured discharge flow rate in GPM"
        Write-Host "IDN                 Read chiller model"
        Write-Host "VFDPWR?             Read current load in kw based on relative percent usage of maximum compressor usage (25kW)"
        Write-Host "VFDACTPRESSURE?     Read current measured discharge pressure in PSI"
        Write-Host "SETTEMP?            Read current setpoint temperature"
        Write-Host "TEMP?               Read current measured discharge temperature"
        Write-Host "FLTS1A?             Read alarm flags 1-2"
        Write-Host "AUXPCWTEMP?         NOT SUPPORTED"
        Write-Host "VFDFLOWRATE?        NOT SUPPORTED`n"
    }

    [int]connect_tcp() {
        while ($true) {
            try { # try to connect via TCP
                Write-Host "Connecting TCP->IOLAN: " -NoNewline
                $this.TCP.Connect($this.TCPEND) # open the serial port
                Write-Host "Connected" -ForegroundColor Green
                return 1
            }catch{ # if failed show error and exit
                Write-Host ("FAILED") -ForegroundColor Red
                Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
            }

            $input = Read-Host "TCP connection needed: type 'exit' or enter to try again"
            if ($input -eq "exit") { # exit if needed char
                return -1
            else 
                continue
            }
        }
        return -1
    }

    [void]send_tcp($tx) {
        # Send ASCII text
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($tx)
        $bytes = $bytes + "`r"
        [void]$this.TCP.Send($bytes)
    }

    [void]recv_tcp() {
        # Receive response via tcp
        if ($this.TCP.Poll(1000000, [System.Net.Sockets.SelectMode]::SelectRead)) {
            # atempt to read count chars from TCP into buffer
            $count = $this.TCP.Receive($this.rxbuff)
            
            if ($count -gt 0) {
                $raw_tcp_rx = [System.Text.Encoding]::ASCII.GetString($this.rxbuff,0,$count)
                Write-Host "TCP RX: `"$raw_tcp_rx`"`n"
            }
        } else {
            Write-Host "(No response) `n"
        }
        [Array]::Clear($this.rxbuff, 0, $this.rxbuff.Length)
    }

} # END  TEST CLASS  ===========================================================

# Main things ==================================================================

$test = [test]::new()
$test.main()
$test.des()

# End ==========================================================================