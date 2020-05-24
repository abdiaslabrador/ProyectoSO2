#Ventana 
Add-Type -assembly System.Windows.Forms
$main_form = New-Object System.Windows.Forms.Form
$main_form.Text ='Visor de Procesos'
$main_form.Width = 680
$main_form.Height = 360
$main_form.AutoSize = $false
$main_form.FormBorderStyle = 'FIxedDIalog'

#GUI para procesos
$texbox = New-Object System.Windows.Forms.DataGridView
$texbox.Width = 650
$texbox.Height = 270
$texbox.readonly=$true
$texbox.Location  = New-Object System.Drawing.Point(10, 40)
$texbox.SelectionMode = 1;
$texbox.allowusertoaddrows=$false
$texbox.allowusertoresizeRows=$false
$texbox.ColumnHeadersVisible = $true
$texbox.RowHeadersVisible = $false
$texbox.AutoSizeColumnsMode = 'Fill'
$texbox.ScrollBars = "Vertical"
$main_form.Controls.Add($texbox)
#--------------------------------------------------------

$global:MODE=0
$global:CURPID=0;

#Botones 

$Button = New-Object System.Windows.Forms.Button
$Button.Location = New-Object System.Drawing.Size(10,10)
$Button.Size = New-Object System.Drawing.Size(120,23)
$Button.Text = "Escanear Procesos"
$main_form.Controls.Add($Button)
$Button.Add_Click({$global:MODE=0})

$Buttoncpu = New-Object System.Windows.Forms.Button
$Buttoncpu.Location = New-Object System.Drawing.Size(140,10)
$Buttoncpu.Size = New-Object System.Drawing.Size(120,23)
$Buttoncpu.Text = "CPU > 10%"

$main_form.Controls.Add($Buttoncpu)

$Buttoncpu.Add_Click({$global:MODE=1})
$Buttonmem = New-Object System.Windows.Forms.Button
$Buttonmem.Location = New-Object System.Drawing.Size(270,10)
$Buttonmem.Size = New-Object System.Drawing.Size(120,23)
$Buttonmem.Text = "RAM > 8%"
$main_form.Controls.Add($Buttonmem)
$Buttonmem.Add_Click({$global:MODE=2})

$Buttonbu = New-Object System.Windows.Forms.Button
$Buttonbu.Location = New-Object System.Drawing.Size(400,10)
$Buttonbu.Size = New-Object System.Drawing.Size(120,23)
$Buttonbu.Text = "Terminar Proceso"
$main_form.Controls.Add($Buttonbu)
    
$Buttonbu.Add_Click({
    $i = $texbox.CurrentRow.Index;  
    if($i -ne $null)
    {Stop-Process ($texbox.Rows[$i].Cells[1].Value);}
})

$Buttonb = New-Object System.Windows.Forms.Button
$Buttonb.Location = New-Object System.Drawing.Size(530,10)
$Buttonb.Size = New-Object System.Drawing.Size(120,23)
$Buttonb.Text = "Terminar Procesos"
$main_form.Controls.Add($Buttonb)

$Buttonb.Add_Click({$global:MODE=3})

#--------------------------------------------------------
$nombres_de_windows=  "powershell", "cmd","ApplicationFrameHost", "MicrosoftEdge",
"WindowsInternal", "WinStore.App","SystemSettings", 
"WindowsInternal.ComposableShell.Experiences.TextInput.InputApp", 
"MicrosoftEdgeCP", "MicrosoftEdge"
$global:ArrayList = New-Object System.Collections.ArrayList

$global:pwshv = ((Get-Host).Version.Major)
$global:rambyte =((Get-WmiObject Win32_ComputerSystem).totalphysicalmemory)

function GET_STAMP
{
    $gp = gps | ? {$_.mainwindowtitle.length -ne 0} | where-object {$nombres_de_windows -notcontains $_.ProcessName}
    foreach($x in $gp){$global:ArrayList.add($x.Id)}

    $programs = @{}
    $g = Get-WmiObject Win32_PerfFormattedData_PerfProc_Process  | Where-Object { $_.name -inotmatch '_total|idle' }

    foreach($j in $g)
    {
        foreach($k in $gp)
        {
           if($j.Name.equals($k.ProcessName) -or $j.Name.contains($k.ProcessName+"#"))
           {
               #"Process={0,-25} CPU_Usage={1,-12} Memory_Usage_(MB)={2,-16}" -f `
               #$j.Name,$j.PercentProcessorTime,([math]::Round($j.WorkingSetPrivate/1Mb,2))
               if($programs[$k.ProcessName] -eq $null)
                {
                     $programs.Add(
                                    $k.ProcessName,  @{
                                                        name = ($k.ProcessName);
                                                        id   = ($k.Id);
                                                        memory = ($j.WorkingSetPrivate);
                                                        processor = ($j.PercentProcessorTime)
                                           }
                                   )
                }
                else
                {
                    $programs[$k.ProcessName].memory+=($j.WorkingSetPrivate)
                }
           }
        }
    }

    $w= $gp | foreach-object{
      
        
        $tmp=@{
            PID=$_.Id;
            Nombre=$programs[$_.ProcessName].name;
            RAM= ([math]::Round((($programs[$_.ProcessName].memory/1mb )),3))#$global:rambyte
            CPU= $programs[$_.ProcessName].processor;
            }
        New-Object -TypeName PSObject -prop $tmp;
      }

    return $w
}

Function Stop
{
    param($PROCESOS)
    $PIDS = ($PROCESOS | Select-Object -Property PID).PID
    if($PIDS -ne $null)
    {Stop-Process $PIDS}
    return $PROCESOS
}

Function Info
{
    param($CPUMin,$RAMMin)
    filter OK {
            if( ($_.RAM -gt $RAMMin -or ($_.RAM -ne $null -and $RAMMin -eq 0.0)) -and 
            (    $_.CPU -gt $CPUMin -or ($_.CPU -ne $null -and $CPUMin -eq 0.0)) )
            {$_}
    }

    return (GET_STAMP | OK);
}

Function GET_DATA
{   #Boton selector
    param($mode)
    $Object = $null
    if($mode -eq 0){$Object = (Info 0.0 0.0); return $Object}  #todos los procesos
    if($mode -eq 1){$Object = (Info 10.0 0.0); return $Object} #procesos cpu con con uso de 10%cpu
    if($mode -eq 2){$Object = (Info 0.0 8.0); return $Object}  #procesos memoria con consumo de 8%ram
    if($mode -eq 3){$Object = (Stop(Info 10.0 8.0)); return $Object} #eliminar los procesos con uso de 10%cpu y 8%ram del computador
}

$global:currentIndex=0;

Start-Sleep -m 500

$timer = new-OBject System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_tick({Update})  
$timer.start()

$DATA = GET_DATA($global:MODE)

Function Update()
{
   $DATA = GET_DATA($global:MODE)
try{
    $global:currentIndex = $texbox.CurrentRow.Index;
    $currentCol = $texbox.CurrentCol.Index;
    $currentRow = $texbox.FirstDisplayedScrollingRowIndex;    
    $texbox.datasource = [collections.arraylist]$DATA;
    $texbox.CurrentCell = $texbox.Rows[$global:currentIndex].Cells[0];
    $texbox.FirstDisplayedScrollingRowIndex = $currentRow;  
    $texbox.update();
    }
    catch{}  
}
$main_form.ShowDialog();