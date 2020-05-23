cls

$ms =600
$lim=20

$global:pwshv = ((Get-Host).Version.Major)
$global:ramkb = 0
if($isLinux){$global:ramkb = [int](((vmstat -s)[0]) | grep -o '[[:digit:]]*')}
if($isWindows -or ($global:pwshv -lt 6))
{$global:ramkb =((Get-WmiObject Win32_ComputerSystem).totalphysicalmemory)/1024}


$global:STAMP_BACKUP=$null
$global:CPU_TIME=$null

function GET_UPTIME_MS
{
    if($global:pwshv -lt 6)
    { 
        $wmi = (get-wmiobject win32_operatingsystem); $wmi =(New-TimeSpan $($wmi.ConvertToDateTime($wmi.lastbootuptime)) $(Get-date)).TotalMilliseconds
        return $wmi;
    }
    else
    {return (Get-Uptime).TotalMilliseconds}
}

Function GET_PROCESSES
{
    $gp = Get-Process | Where-OBject {$_.CPU -ne $null}
    if($global:pwshv -ge 7)
    {$gp = $gp | Where-Object -Property SI -ne 0}
    
    $gp= $gp | foreach-object{
    $tmp=@{
        PID=$_.ID;
        Name=$_.ProcessName;
        Mem=($_.WS+$_.PM+$_.NPM);
        CPU= ($_.TotalProcessorTime).TotalMilliseconds
    }
    New-Object -TypeName PSObject -prop $tmp;
    }
   
    return $gp
}

Function GET_STAMP
{
    $tmp_time = (GET_UPTIME_MS);
    $tmp = GET_PROCESSES
    $RETURN= $tmp | ForEach-Object {$ID=$_.PID;
		    filter _PAR{if($_.PID -eq $ID){$_}};
               
         $tmp2=@{
            PID=$_.PID;
            Name=$_.Name;
            Mem=[math]::round((($_.Mem/1024)/$global:ramkb)*100.0,3);
            CPU=if(($par=($global:STAMP_BACKUP|_PAR)) -eq $null){0}
            else{[math]::round((($_.CPU-($par|select-Object -first 1).CPU)/($tmp_time-$global:CPU_TIME))*100.0,3)};}      
		    New-Object -TypeName PSObject -prop $tmp2;
            }

    $global:CPU_TIME = $tmp_time;
    $global:STAMP_BACKUP=$tmp;
    return $RETURN
}

Function Info
{
    param($CPUMin,$RAMMin)
    filter OK {if($_.Mem -GT $RAMMin -and $_.CPU -GT $CPUMin){$_}}
    return (GET_STAMP | OK | Sort-Object -Descending -Property CPU)
    
}

Function Stop
{
    param($PROCESOS)
    $PIDS = ($PROCESOS | Select-Object -Property PID).PID
    if($PIDS -ne $null)
    {Stop-Process $PIDS}
    return $PROCESOS
}

Function Format
{
    param($PROCESOS)
    if($PROCESOS -eq $null){return $null}
    return $PROCESOS | Format-Table @{Label="PID";Expression={$_.PID}},@{Label="Nombre";Expression={$_.Name}},@{Label="Memoria(%)";Expression={$_.Mem}},@{Label="CPU(%)";Expression={$_.CPU}};
}

Function GET_DATA
{
    param($mode)
    $Object = $null
    if($mode -eq 0){$Object = (Info 0.0 0.0)}
    if($mode -eq 1){$Object = (Info 10.0 0.0)}
    if($mode -eq 2){$Object = (Info 0.0 8.0)}
    if($mode -eq 3){$Object = (Stop(Info 10.0 8.0))}
    return Out-String -stream -InputObject (Format($Object))
}

$cond = $true
$terminado = $false
$global:limsup=0
$MODE=0

Function GET_MODE
{
    param($run)
    do{
	if ([Console]::KeyAvailable)
	{
	    switch($K = ([Console]::ReadKey($false)).Key)
	    {
		([ConsoleKey]::UpArrow){$global:limsup-=4;if($global:limsup -lt 0){$global:limsup=0}}
		([ConsoleKey]::DownArrow){$global:limsup+=4}
		([ConsoleKey]::D0){$MODE=0;$run=$false}
		([ConsoleKey]::D1){$MODE=1;$run=$false}
		([ConsoleKey]::D2){$MODE=2;$run=$false}
		([ConsoleKey]::D3){$MODE=3;$run=$false}
		([ConsoleKey]::D4){$MODE=4;$run=$false;}
	    }
	    while([Console]::KeyAvailable)
	    {[Console]::ReadKey($false).Key|Out-Null;}
	}
	Start-Sleep -ms 33
    }while($run -eq $true)
    return $MODE;
}


Write-Host "-- Manual --"
Write-Host "`n"
Write-Host "Presione '0' para mostrar procesos"
Write-Host "Presione '1' para mostrar procesos con CPU>10%"
Write-Host "Presione '2' para mostrar procesos con RAM>8%"
Write-Host "Presione '3' para terminar procesos con RAM>8% y CPU>10%"
Write-Host "Presione '4' para salir"
Write-Host "`n"
Write-Host "Use las flechas direccionales para desplazarse"
Write-Host "`n"
write-host "Puede presionar los botones en cualquier momento"
Write-Host "`n"
Write-Host "Presione cualquier tecla para continuar"
$MODE = GET_MODE($true)
cls

$global:STAMP_BACKUP=GET_PROCESSES
$global:CPU_TIME = (GET_UPTIME_MS);

Write-Host "Preparando..."
Start-Sleep -m 1000
cls

while($cond -eq $true){

    $MODE = GET_MODE($false)
    if($MODE -eq 4){break;}

    if($terminado -eq $false)
    {$DATA = GET_DATA($MODE)}

    $liminf=$simsup+$lim

    cls
    Write-Host MODO: $MODE 
    if($DATA -ne $null)
    {
	for($i=$limsup;$i -le $liminf;$i++)
	{Write-Output $DATA[$i]}
    }

    Start-Sleep -m $ms
}
