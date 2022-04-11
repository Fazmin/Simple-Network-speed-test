<#
Simple Network Speed Test v.1.1
Description: This script will create a dummy file, default size of 1GB, and copy to and from a target server.  The Mbps will be determined from the time it 
takes to perform this operation.
Author : Fazmin Nizam
Example: .\Network-SpeedTest.ps1 -path \\engfilew...\<folder name> -Size 300 -Verbose
#>
#requires powershell -Version 3.0
[CmdletBinding()]
Param (
    [Parameter(Mandatory,ValueFromPipeline,HelpMessage="Enter UNC's to server to test (A data file will be created)")]
    [String[]]$Path,
    [ValidateRange(1,1000)]
    # Default is set to 1GB
    [int]$Size = 1000
)

Begin {
    #Creating the testdata file
    Write-Verbose "$(Get-Date): Network-SpeedTest Script begins"
    Write-Verbose "$(Get-Date): Create dummy data file, Size: $($Size)MB"
    $Source = $PSScriptRoot
    Remove-Item $Source\Testdata.txt -ErrorAction SilentlyContinue
    Set-Location $Source
    $DummySize = $Size * 1048576
    $CreateMsg = fsutil file createnew testdata.txt $DummySize

    Try {
        $TotalSize = (Get-ChildItem $Source\Testdata.txt -ErrorAction Stop).Length
    }
    Catch {
        Write-Warning "Unable to locate dummy data file"
        Write-Warning "Create Message: $CreateMsg"
        Write-Warning "Last error: $($Error[0])"
        Exit
    }
    Write-Verbose "$(Get-Date): Source for dummy data file: $Source\Testdata.txt"
    $RunTime = Get-Date
}

Process {
    ForEach ($ServerPath in $Path)
    {   $Server = $ServerPath.Split("\")[2]
        $Target = "$ServerPath\SpeedTest"
        Write-Verbose "$(Get-Date): Checking speed for $Server..."
        Write-Verbose "$(Get-Date): Destination: $Target"
        
        If (-not (Test-Path $Target))
        {   Try {
                New-Item -Path $Target -ItemType Directory -ErrorAction Stop | Out-Null
            }
            Catch {
                Write-Warning "Problem creating $Target folder because: $($Error[0])"
                [PSCustomObject]@{
                    Server = $Server
                    TimeStamp = $RunTime
                    Status = "$($Error[0])"
                    WriteTime = New-TimeSpan -Days 0
                    WriteMbps = 0
                    ReadTime = New-TimeSpan -Days 0
                    ReadMbps = 0
                }
                Continue
            }
        }
        
        # Read write test
        Try {
            Write-Verbose "$(Get-Date): Write Test..."
            $WriteTest = Measure-Command { 
                Copy-Item $Source\Testdata.txt $Target -ErrorAction Stop
            }
            
            Write-Verbose "$(Get-Date): Read Test..."
            $ReadTest = Measure-Command {
                Copy-Item $Target\Testdata.txt $Source\TestRead.txt -ErrorAction Stop
            }
            $Status = "OK"
            $WriteMbps = [Math]::Round((($TotalSize * 8) / $WriteTest.TotalSeconds) / 1048576,2)
            $ReadMbps = [Math]::Round((($TotalSize * 8) / $ReadTest.TotalSeconds) / 1048576,2)
        }
        Catch {
            Write-Warning "Problem during speed test: $($Error[0])"
            $Status = "$($Error[0])"
            $WriteMbps = $ReadMbps = 0
            $WriteTest = $ReadTest = New-TimeSpan -Days 0
        }
        
        [PSCustomObject]@{
            Server = $Server
            TimeStamp = $RunTime
            Status = "OK"
            WriteTime = $WriteTest
            WriteMbps = $WriteMbps
            ReadTime = $ReadTest
            ReadMbps = $ReadMbps
        }
        Remove-Item $Target\Testdata.txt -ErrorAction SilentlyContinue
        Remove-Item $Source\TestRead.txt -ErrorAction SilentlyContinue
    }
}

End {
    Remove-Item $Source\Testdata.txt -ErrorAction SilentlyContinue
    Write-Verbose "$(Get-Date): Network-SpeedTest completed!"
}