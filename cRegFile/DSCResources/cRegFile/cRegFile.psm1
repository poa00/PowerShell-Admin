function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key,

        [parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [System.String]$RegFilePath
    )

    If (Test-Path -Path $Key -PathType Container) {

        Write-Verbose "The registry key $Key was found"

        Write-Verbose "Exporting the key to a .reg file"

        # Building the arguments for the reg.exe command
        $KeySplit = $Key -split '\\'
        $KeySplit[0] = $KeySplit[0] -replace ':'
        $KeyNameForReg = $KeySplit -join '\'
        $keyBaseName = $KeySplit[-1]
        $RegFilePath = $env:TEMP + "\" + $keyBaseName + ".reg"
        $Arguments = "export $KeyNameForReg $RegFilePath /y"

        Try {
            Start-Process -FilePath C:\Windows\System32\reg.exe -ArgumentList $Arguments -NoNewWindow -Wait -ErrorAction Stop
        }
        Catch {
            Write-Verbose "There was a problem while running reg.exe with the following arguments : $Arguments"
            $RegFilePath = ''
        }
        $returnValue = @{
            Key = $Key
            RegFilePath = $RegFilePath
        }
    }

    Else {
        Write-Verbose "The registry key $Key could not be found or is not a registry key path"

        $returnValue = @{
            Key = $Key
            RegFilePath = ''
        }
    }
    $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key,

        [parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [System.String]$RegFilePath
    )

    # Building the arguments for the reg.exe command
    $Arguments = "import $RegFilePath"

    Try {
        Start-Process -FilePath C:\Windows\System32\reg.exe -ArgumentList $Arguments -NoNewWindow -Wait -ErrorAction Stop
    }
    Catch {
        Write-Verbose "There was a problem while running reg.exe with the following arguments : $Arguments"
        Write-Error "$($_.Exception.Message)"
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Key,

        [parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [System.String]$RegFilePath
    )
    # Declaring the output variable upfront and assigning it a default value
    [System.Boolean]$result = $False

    #region Validating that the root key in the .reg file matches the specified registry key
    $KeyFromRegFile = (Select-String -Path $RegFilePath -Pattern "\[[\w\d\\\{\}-]+\]" -List).Line -replace '[\[\]]',''
    Write-Verbose "Registry key derived from the content of the .reg file : $KeyFromRegFile"

    $KeyFromRegFileSplit = $KeyFromRegFile -split '\\'
    $KeyFromRegFileNoHive = ($KeyFromRegFileSplit | Select-Object -Skip 1) -join '\'

    $KeySplit = $Key -split '\\'
    $KeyNoHive = ($KeySplit | Select-Object -Skip 1) -join '\'

    If ($KeyFromRegFileNoHive -ne $KeyNoHive) {
        Throw "The root key in the file $RegFilePath doesn't match the specified key : $Key"
    }
    #endregion Validating that the root key in the .reg file
    
    If (Test-Path -Path $Key -PathType Container) {
        
        Write-Verbose "The registry key $Key was found"

        Write-Verbose "Exporting the key to a .reg file"

        # Building the arguments for the reg.exe command
        $KeySplit[0] = $KeySplit[0] -replace ':'
        $KeyNameForReg = $KeySplit -join '\'
        $keyBaseName = $KeySplit[-1]
        $RegFilePathTarget = $env:TEMP + "\" + $keyBaseName + ".reg"
        $Arguments = "export $KeyNameForReg $RegFilePathTarget /y"

        Try {
            Start-Process -FilePath C:\Windows\System32\reg.exe -ArgumentList $Arguments -NoNewWindow -Wait -ErrorAction Stop
        }
        Catch {
            Write-Verbose "There was a problem while running reg.exe with the following arguments : $Arguments"
            Throw "$($_.Exception.Message)"
        }

        # Generating a hash for the reference .reg file and the one exported on the target node
        $RegFileHash = (Get-FileHash -Path $RegFilePath).Hash
        Write-Verbose "Hash value of the reference .reg file : $RegFileHash"

        $RegFileHashTarget = (Get-FileHash -Path $RegFilePathTarget).Hash
        Write-Verbose "Hash value of the .reg file on the target node : $RegFileHashTarget"

        # Using the hash values to evaluate if the contents of the .reg files are identical
        $result = $RegFileHash -eq $RegFileHashTarget
    }
    Else {
        Write-Verbose "The registry key $Key could not be found or is not a registry key path"
        $result = $False
    }

    $result
}


Export-ModuleMember -Function *-TargetResource