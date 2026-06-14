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

    # Serial Port Object
    [System.IO.Ports.SerialPort]$DB9

    # TCP Socket Object
    [System.Net.Sockets.Socket]$TCP

    # TCP EndPoint Object
    [System.Net.IPEndPoint]$TCPEND

    #buffer
    $buffer

    # Constructor ==============================================================
    test() {
        # Set TCP Socket Data
        $this.TCP = [System.Net.Sockets.Socket]::new(
            [System.Net.Sockets.AddressFamily]::InterNetworkV6,
            [System.Net.Sockets.SocketType]::Stream,
            [System.Net.Sockets.ProtocolType]::Tcp
        )

        # Set TCP Endpoint Data
        # Parse IPv6 WITHOUT interface name
        $ip = [System.Net.IPAddress]::Parse("fe80::280:d4ff:fe32:80a8")

        $this.TCPEND = [System.Net.IPEndPoint]::new(
            $ip,                # 
            10010               # port used
        )

        # Set Serial Port Data
        $this.DB9               = New-Object System.IO.Ports.SerialPort
        $this.DB9.PortName      = "/dev/ttyUSB0"
        $this.DB9.BaudRate      = 19200
        $this.DB9.Parity        = [System.IO.Ports.Parity]::Even
        $this.DB9.DataBits      = 7
        $this.DB9.StopBits      = [System.IO.Ports.StopBits]::One
        $this.DB9.Handshake     = [System.IO.Ports.Handshake]::None
        $this.DB9.ReadTimeout   = 200
        $this.DB9.WriteTimeout  = 200

        #create buffers
        $this.buffer = New-Object byte[] 40961
    }

    [void]des() {
        $this.TCP.Close()
        $this.DB9.Close()
    }

    [void]TCP_connect() {


    }

    # Connecting to IOLAN via DB9===============================================

    [void]DB9_connect() {


    }

    # Main Loop ================================================================



    [void]main() {

        # try to connect via TCP
        while (1){
            try{
                Write-Host "Connecting TCP->IOLAN: " -NoNewline
                $this.TCP.Connect($this.TCPEND) # open the serial port
                Write-Host "Connected" -ForegroundColor Green
            }catch{
                Write-Host ("FAILED") -ForegroundColor DarkYellow
                Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
                $exit = Read-Host "Enter exit or enter to try again"

                if ($exit -eq "exit"){
                    return -1;
                }else{
                    continue;
                }
            } break;
        }

        # Connect via serial DB9
        $validPorts = [System.IO.Ports.SerialPort]::GetPortNames()
        Write-Host "Valid Port Names: $validPorts"

        Write-Host "Connecting SIM->IOLAN: " -NoNewline
        try{
            $this.DB9.Open()
            Write-Host "Connected`n" -ForegroundColor Green
        }catch{
            Write-Host ("FAILED") -ForegroundColor DarkYellow
            Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Main loop
        while ($true) {
            $tx = Read-Host "TCP TX"

            if ($tx -eq "exit") {
                break}

            # Send ASCII text
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($tx)
            [void]$this.TCP.Send($bytes)

            # wait 50 ms before receiving message
            Start-Sleep -Milliseconds 50

            # receive data via serial
            $raw_DB9_rx = $this.DB9.ReadExisting()

            Write-Host ("SIM RX: :`"$raw_DB9_rx`"")

            # send serial send example serial reDB9onse
            $example = ":01040200CE2B"

            $this.DB9.Write($example + "`r`n")
            Write-Host("SIM TX: `"$example`"")

            # Receive response via tcp
            if ($this.TCP.Poll(1000000, [System.Net.Sockets.SelectMode]::SelectRead)) {
                $count = $this.TCP.Receive($this.buffer)

                if ($count -gt 0) {
                    $raw_tcp_rx = [System.Text.Encoding]::ASCII.GetString($this.buffer,0,$count)

                    Write-Host "TCP RX: `":$raw_tcp_rx`" `n"
                }
            } else {
                Write-Host "(No response) `n"
            }
        } # end Loop

    } # END MAIN

} # END  TEST ==================================================================

# Main things ==================================================================

$test = [test]::new()
$test.main()
$test.des()

# End ==========================================================================