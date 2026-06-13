# Connecting to IOLAN via TCP===============================================================================================



# $Inteface_list = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

$IOLAN_IP = "fe80::280:d4ff:fe32:80a8" # Hardcoded for now (next-step: dynamic checking of single valid IP on each interface list)
$Ethernet_Interface = "enp0s31f6"      # Hardcoded for now (next-step: dynamic testing and list with interface_list)

$ADDR = $IOLAN_IP + "%"
$ADDR = $ADDR + $Ethernet_Interface

$addr = [System.Net.IPAddress]::Parse("fe80::280:d4ff:fe32:80a8%enp0s31f6")


$tcp_config = New-Object System.Net.IPEndPoint($addr,10010)

$tcp = New-Object System.Net.Sockets.Socket(
    [System.Net.Sockets.AddressFamily]::InterNetworkV6,
    [System.Net.Sockets.SocketType]::Stream,
    [System.Net.Sockets.ProtocolType]::Tcp
)

while (1){
    try{
        Write-Host "Connecting TCP->IOLAN: " -NoNewline
        $tcp.Connect($tcp_config) # open the serial port
        Write-Host "Connected" -ForegroundColor Green
    } catch {
        Write-Host ("FAILED") -ForegroundColor DarkYellow
        Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
        $exit = Read-Host "Enter exit or enter to try again"

        if ($exit -eq "exit"){
            return;
        }else{
            continue;
        }
    }
    break;
}

# Connecting to IOLAN via DB9===============================================================================================
$DB9                 = New-Object System.IO.Ports.SerialPort
$DB9.PortName        = "/dev/ttyUSB0"
$DB9.BaudRate        = 19200
$DB9.Parity          = [System.IO.Ports.Parity]::Even
$DB9.DataBits        = 7
$DB9.StopBits        = [System.IO.Ports.StopBits]::One
$DB9.Handshake       = [System.IO.Ports.Handshake]::None
$DB9.ReadTimeout     = 200
$DB9.WriteTimeout    = 200

$validPorts = [System.IO.Ports.SerialPort]::GetPortNames()

Write-Host "Valid Port Names: $validPorts"

Write-Host "Connecting SIM->IOLAN: " -NoNewline
try{
    $DB9.Open()
    Write-Host "Connected`n" -ForegroundColor Green
}catch{
    Write-Host ("FAILED") -ForegroundColor DarkYellow
    Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
}


$buffer = New-Object byte[] 40961

# Main Loop ================================================================================================================

while ($true) {
    $tx = Read-Host "TCP TX"

    if ($tx -eq "exit") {
        break
    }

    # Send ASCII text
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($tx)
    [void]$tcp.Send($bytes)

    # wait 200 ms before receiving message
    Start-Sleep -Milliseconds 200

    # receive data via serial
    $raw_DB9_rx = $DB9.ReadExisting()

    Write-Host ("SIM RX: :`"$DB9_rx`"")
    
    # send serial send example serial reDB9onse
    $example = ":01040200CE2B"

    $DB9.Write($example + "`r`n")
    Write-Host("SIM TX: `"$example`"")

    # Receive reDB9onse via tcp
    if ($tcp.Poll(1000000, [System.Net.Sockets.SelectMode]::SelectRead)) {
        $count = $tcp.Receive($buffer)

        if ($count -gt 0) {
            $raw_tcp_rx = [System.Text.Encoding]::ASCII.GetString($buffer,0,$count)

            Write-Host "TCP RX: `":$raw_tcp_rx`" `n"
        }
    } else {
        Write-Host "(No reDB9onse) `n"
    }
}

$tcp.Close()
$DB9.Close()

# END ======================================================================================================================