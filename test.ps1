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
        $this.DB9.PortName      = "COM9"
        $this.DB9.BaudRate      = 9600
        $this.DB9.Parity        = [System.IO.Ports.Parity]::Even
        $this.DB9.DataBits      = 7
        $this.DB9.StopBits      = [System.IO.Ports.StopBits]::One
        $this.DB9.Handshake     = [System.IO.Ports.Handshake]::None
        $this.DB9.ReadTimeout   = 200
        $this.DB9.WriteTimeout  = 200

        #create buffers
        $this.buffer = New-Object byte[] 1024
    }

    [void]des() {
        $this.TCP.Close()
        $this.DB9.Close()
    }

    # Main Loop ================================================================

    [void]main() {

        #Configure DB9 port name
        while (1) {

            $validPorts = [System.IO.Ports.SerialPort]::GetPortNames()
            Write-Host ("Valid COM ports:`n"  + ($validPorts -join "`n")) -ForegroundColor Green

            $input = Read-Host "Enter COM port or 'idk' to use unplug and plug detection"
            if ($input -ne "idk") {

                # check coms and make sure input is a valid com
                if ($validPorts -contains $input) {
                    Write-Host "Valid COM port detected: $input" -ForegroundColor Green
                    break;
                }else{
                    Write-Host "Invalid COM port" -ForegroundColor Red
                    continue
                }

                $this.DB9.PortName = $input
                Write-Host ("COM Port set to: " + $input) -ForegroundColor Green
            }

            $reply = ""

            Write-Host "Please confirm that your coms cable is NOT plugged in." -ForegroundColor Green
            Read-Host "Press Enter to continue"
            Write-Host "Fetching COMS..." -ForegroundColor Green

            $hay = [System.IO.Ports.SerialPort]::GetPortNames()

            Write-Host ("COM Ports: " + ($hay -join " ")) -ForegroundColor Green

            Write-Host "Please confirm that your coms cable IS plugged in." -ForegroundColor Green
            Read-Host "Press Enter to continue"

            $haystack = [System.IO.Ports.SerialPort]::GetPortNames()

            # get the first string that is in haystack but not in hay
            $COM = $haystack | Where-Object {$_ -notin $hay} # get COM ports

            Write-Host ("COM Port should be: " + ($COM)) -ForegroundColor Green

            $this.DB9.Close() # close port if open
            $this.DB9.PortName = $COM
        }

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
                    return;
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

            $this.DB9.DiscardInBuffer()

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

            Write-Host ("SIM RX: `"$raw_DB9_rx`"")

            # send serial send example serial response
            $example = ":01040200CE2B"

            $this.DB9.Write($example)
            Write-Host("SIM TX: `"$example`"")

            # Receive response via tcp
            if ($this.TCP.Poll(1000000, [System.Net.Sockets.SelectMode]::SelectRead)) {
                $count = $this.TCP.Receive($this.buffer)
                
                if ($count -gt 0) {
                    $raw_tcp_rx = [System.Text.Encoding]::ASCII.GetString($this.buffer,0,$count)
                
                    Write-Host "TCP RX: `"$raw_tcp_rx`n"
                }

            } else {
                Write-Host "(No response) `n"
            }

            [Array]::Clear($this.buffer, 0, $this.buffer.Length)
        } # end Loop

    } # END MAIN

} # END  TEST ==================================================================

# Main things ==================================================================

$test = [test]::new()
$test.main()
$test.des()

# End ==========================================================================