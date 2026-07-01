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

    #buffers
    $rxbuff
    $txbuff

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
        $ip = [System.Net.IPAddress]::Parse("fe80::280:d4ff:fe32:80a8%2")

        $this.TCPEND = [System.Net.IPEndPoint]::new(
            $ip,                # 
            10010               # port used
        )

        # Set Serial Port Data
        $this.DB9               = New-Object System.IO.Ports.SerialPort
        $this.DB9.PortName      = "/dev/ttyUSB0"
        $this.DB9.BaudRate      = 9600
        $this.DB9.Parity        = [System.IO.Ports.Parity]::Even
        $this.DB9.DataBits      = 7
        $this.DB9.StopBits      = [System.IO.Ports.StopBits]::One
        $this.DB9.Handshake     = [System.IO.Ports.Handshake]::None
        $this.DB9.ReadTimeout   = 200
        $this.DB9.WriteTimeout  = 200

        #create buffers
        $this.rxbuff = New-Object byte[] 1024
        $this.txbuff = New-Object byte[] 1024
    }

    [void]des() {
        $this.TCP.Close()
        $this.DB9.Close()
    }

    # Main Loop ================================================================

    [void]main() {

        $good_tcp = $this.connect_tcp();

        $good_db9 = $this.connect_db9();

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

                    if ($good_db9 -gt 0){
                        $this.sim_recv_send()
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
        Write-Host "PWM?                Start the chiller via serial"
        Write-Host "AUXPCFLOWRATE?      Stop the chiller via serial"
        Write-Host "IDN                 Read the chiller data"
        Write-Host "VFDPWR?             Attempt to connect to the chiller"
        Write-Host "VFDACTPRESSURE?     Set the chiller slave address"
        Write-Host "SETTEMP?            Read the set discharge temp"
        Write-Host "TEMP?               Read the present discharge temp"
        Write-Host "FLTS1A?             Read alarm flags 1-2`n"
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

    [int]connect_db9() {
        while ($true) {
            try { # try to connect via DB9 with hardcoded vals
                Write-Host "Connecting IOLAN->SIM: " -NoNewline
                $this.DB9.Open()
                Write-Host "Connected" -ForegroundColor Green
                return 1
            }catch{
                # show failed port name
                $port = $this.DB9.PortName
                Write-Host ("FAILED using $port`n") -ForegroundColor Red
            }

            # show valid port options
            $validPorts = [System.IO.Ports.SerialPort]::GetPortNames()
            Write-Host ("Valid COM ports:"  + ($validPorts -join " ")) -ForegroundColor Green

            # menu prompt
            $input = Read-Host "Enter COM port, 'exit', or 'idk' to use unplug and plug detection"
            if ($input -eq "exit") { # exit if needed char
                return -1
            }if ($input -ne "idk") {
                # check coms and make sure input is a valid comchar
                if ($validPorts -contains $input) {
                    Write-Host "COM Port is Valid: $input" -ForegroundColor Green

                }else{ 
                    Write-Host "Invalid COM port" -ForegroundColor Red
                    continue
                }
                $this.DB9.PortName = $input
                Write-Host ("COM Port set to: $input `n") -ForegroundColor Green
                continue
            }

            $reply = ""
            Write-Host "Please confirm that your coms cable is NOT plugged in."     -ForegroundColor Green
            Read-Host "Press Enter to continue"
            Write-Host "Fetching COMS..." -ForegroundColor Green
            $hay = [System.IO.Ports.SerialPort]::GetPortNames()
            Write-Host ("COM Ports: " + ($hay -join " ")) -ForegroundColor Green
            Write-Host "Please confirm that your coms cable IS plugged in." -ForegroundColor    Green
            Read-Host "Press Enter to continue"
            $haystack = [System.IO.Ports.SerialPort]::GetPortNames()
            # get the first string that is in haystack but not in hay
            $COM = $haystack | Where-Object {$_ -notin $hay} # get COM ports
            Write-Host ("COM Port should be: " + ($COM)) -ForegroundColor Green
            $this.DB9.Close() # close port if open
            $this.DB9.PortName = $COM
        }
        return -1
    }

    [void]send_tcp($tx) {
        # Send ASCII text
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($tx)
        [void]$this.TCP.Send($bytes)
    }

    [void]sim_recv_send() {
        # flush serial buffer
        $this.DB9.DiscardInBuffer()
        $this.DB9.DiscardOutBuffer()

        # wait 50 ms before receiving message
        Start-Sleep -Milliseconds 50

        # receive data via serial
        $raw_DB9_rx = $this.DB9.ReadExisting()
        Write-Host ("SIM RX: `"$raw_DB9_rx`"")

        # send serial send example serial response
        $example = ":01031800DE0000000000148036000100000008000000020000012C04"
        $this.DB9.Write($example)
        Write-Host("SIM TX: `"$example`"")
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

    [void]send_recv($tx) {
        $this.DB9.DiscardInBuffer()
        $this.DB9.DiscardOutBuffer() 

        # Send ASCII text
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($tx)
        [void]$this.TCP.Send($bytes)
        # wait 50 ms before receiving message
        Start-Sleep -Milliseconds 50
        # receive data via serial
        $raw_DB9_rx = $this.DB9.ReadExisting()
        Write-Host ("SIM RX: `"$raw_DB9_rx`"")

        # send serial send example serial response
        $example = ":01031800DE0000000000148036000100000008000000020000012C04"
        $this.DB9.Write($example)
        Write-Host("SIM TX: `"$example`"")

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