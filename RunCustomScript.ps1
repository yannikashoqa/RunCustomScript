
$Config             = (Get-Content "$PSScriptRoot\XDR-Config.json" -Raw) | ConvertFrom-Json
$XDR_SERVER         = $Config.XDR_SERVER
$TOKEN              = $Config.TOKEN
$SourceFile 		= $Config.SOURCEFILE
$CustomScriptName   = $Config.CUSTOMSCRIPT

$XDR_URI            = "https://" + $XDR_SERVER
$RUN_CUSTOM_SCRIPT_URI   = $XDR_URI + "/v3.0/response/endpoints/runScript"
$QUERY_AGENT_INFO_URI    = $XDR_URI + "/v2.0/xdr/eiqs/query/agentInfo"

if ((Test-Path $SourceFile) -eq $false){
    Write-Host "[ERROR]:        $SourceFile not found."
    Exit
}

$SystemList		= IMPORT-CSV $SourceFile
FOREACH ($Item in $SystemList) {
    $SystemName = $Item.SystemName
	If(Test-Connection -ComputerName $SystemName -Count 1 -Quiet){
	    # Search V1 Database for system
        try {
            $Query_Header = @{
                "Content-Type" = "application/json"
                Authorization = "Bearer $TOKEN"
            }
            $Query_Params = @{
                criteria = @{
                    field = "hostname"
                    value = $SystemName
                }
            }            
            $Query_Payload = $Query_Params | ConvertTo-Json -Depth 4        
            $Query_System_Result = Invoke-RestMethod $QUERY_AGENT_INFO_URI -Method 'POST' -Headers $Query_Header -Body $Query_Payload
            If($Query_System_Result.status -eq "SUCCESS"){    
                $ComputerID = $Query_System_Result.result[0].computerId
                Write-Host "[INFO]      $SystemName Exist in Vision One Database with ComputerID: $ComputerID "
            }
        }
        catch {
            Write-Host "[WARNING]   System $SystemName Does Not Exist in Vision One:  $_"
            Continue
        }

        # Execute the Remote Custom Script
        try {        
            $Headers = @{
                "Content-Type" = "application/json"
                Authorization = "Bearer $TOKEN"
            }            
            $Custom_Script_Payload = @(
                [pscustomobject]@{
                    'endpointName'= $SystemName;
                    'fileName'= $CustomScriptName
                }
            )            
            $Custom_Script_Payload_Json = ConvertTo-Json @($Custom_Script_Payload)
            $Custom_Script_Result = Invoke-RestMethod $RUN_CUSTOM_SCRIPT_URI -Method 'POST' -Headers $Headers -Body $Custom_Script_Payload_Json

        }
        catch {
            Write-Host "[ERROR]     System $SystemName Failed to execute the custom Script:  $_ "
            Continue
        }
	}Else{
		Write-Host "[WARNING]   $SystemName is Offline, make sure the system is powered on and pingable"
	}
}    
