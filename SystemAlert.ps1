# > Publish-AWSPowerShellLambda -ScriptPath .\documents\test\Test.ps1 -Name SystemAlert -Region eu-west-1 -ProfileName nullterrier
# > dotnet-lambda.exe invoke-function SystemAlert --payload "0180"
# API gateway https://hngh0n05va.execute-api.eu-central-1.amazonaws.com/Dev/

#Requires -Modules @{ModuleName='AWSPowerShell.NetCore';ModuleVersion='3.3.343.0'}

$ErrorActionPreference = "Stop"
$snsArn = "arn:aws:sns:eu-west-1:467117906028:SystemAlert"
$storeUrl = "https://www.systembolaget.se/api/assortment/stores/xml"
$closingEarly = ([datetime]"17:00").TimeOfDay #never closed before 17 on normal day
$closingSaturday = ([datetime]"14:00").TimeOfDay  #never closed before 14 on saturday day
$closedTime = ([datetime]"00:00").TimeOfDay
$defaultButik = "0180"
$lookahead = 4

$result = new-object -TypeName psobject
$result | Add-Member -MemberType NoteProperty -Name AlertsGenerated -Value (0)
$result | Add-Member -MemberType NoteProperty -Name DaysProcessed -Value (0)
$result | Add-Member -MemberType NoteProperty -Name Date -Value ([datetime]::now)
$result | Add-Member -MemberType NoteProperty -Name Source -Value ($storeUrl)
$result | Add-Member -MemberType NoteProperty -Name ButikNr -Value ($defaultButik)
$result | Add-Member -MemberType NoteProperty -Name StoreData -Value ($null)
$result | Add-Member -MemberType NoteProperty -Name Lookahead -Value ($lookahead)

Write-Host ("storeUrl: " + $storeUrl)
write-host ("closingEarly: " + $closingEarly)
write-host ("closingSaturday: " + $closingSaturday)
write-host ("defaultButik: " + $defaultButik)
write-host ("snsArn: " + $snsArn)
write-host ("lookahead: " + $lookahead)

function send-message {
    param ([string]$messageText)
    $senderAttribute = -Object Amazon.SimpleNotificationService.Model.MessageAttributeValue
    $senderAttribute = new-Object Amazon.SimpleNotificationService.Model.MessageAttributeValue
    $senderAttribute.StringValue = "SystemAlert"
    $senderAttribute.DataType = "String"
    Publish-SNSMessage -TopicArn $snsArn -Message $messageText -MessageAttributes @{"AWS.SNS.SMS.SenderID" = [Amazon.SimpleNotificationService.Model.MessageAttributeValue]$senderAttribute}
}

#if ($null -eq $LambdaInput) {
#    $butik = $defaultButik
#}
#else {
#    $butik = [string]$LambdaInput
#}

function Load-StoreData {

    Invoke-WebRequest $storeUrl -OutVariable webrequest | out-null
    [xml]$XmlDocument = $webrequest.content

    $store = $XmlDocument.ButikerOmbud.ButikOmbud | Where-Object {$_.nr -eq $defaultButik}  | Select-Object oppettider
    $days = $store.Oppettider.Replace("_*", "`n").split("`n")

    $storeData = New-Object System.Collections.ArrayList($null)

    $days | ForEach-Object {
        $_ -match '(?<date>\d\d\d\d-\d\d-\d+)\;(?<open>\d\d\:\d\d)\;(?<close>\d\d\:\d\d)' | Out-Null
        $storeHours = new-object -TypeName psobject
        $storeHours | Add-Member -MemberType NoteProperty -Name Date -Value ([datetime]$matches.date)
        $storeHours | Add-Member -MemberType NoteProperty -Name Open -Value (([datetime]$matches.open).TimeOfDay)
        $storeHours | Add-Member -MemberType NoteProperty -Name Close -Value (([datetime]$matches.close).TimeOfDay)
        $storeHours | Add-Member -MemberType NoteProperty -Name TriggeredAlert -Value ($false)

        $storeData.Add($storeHours) | out-null
    }
    $result.storedata = $storeData
    return $storedata
}

function Test-OpenHours {
    param ($storeHours)
    [string]$message = $null
    [bool]$warning = $false
    if ($storeHours.open -le $closedTime ) {
        $message = ("Store is closed on " + $storeHours.date.DayOfWeek + " " + $storeHours.date.ToShortDateString() )
        if (($storeHours.date.DayOfWeek -ne [dayofweek]::Sunday) ) {
            $warning = $true
        }
    }
    elseif (($storeHours.date.DayOfWeek -eq [Dayofweek]::Saturday)) {
        if ($storeHours.close -lt $closingSaturday) {
            $warning = $true
            $message = "Store is closing early on " + $storeHours.date.DayOfWeek + " " + $storeHours.date.ToShortDateString() + " " + $storeHours.close
        }
    }
    elseif ($storeHours.close -lt $closingEarly) {
        $message = "Store is closing early on " + $storeHours.date.DayOfWeek + " " + $storeHours.date.ToShortDateString() + " " + $storeHours.close
        $warning = $true
    }

    if (-not $message) {
        $message = "Normal opening hours on " + $storeHours.date.DayOfWeek + " " + $storeHours.date.ToShortDateString() + " " + $storeHours.open + " - " + $storeHours.close
    }

    if ($warning) {
        $storeHours.TriggeredAlert = $true
        $storeHours | Add-Member -MemberType NoteProperty -Name AlertMessage -Value ($message)
        write-host -fore white $message

        if ( ([datetime]::now).AddDays($lookahead).date -eq $storeHours.date) {
            write-warning ("Sending alert: " + $message).Trim()
            $senderAttribute = new-Object Amazon.SimpleNotificationService.Model.MessageAttributeValue
            $senderAttribute.StringValue = "SystemAlert"
            $senderAttribute.DataType = "String"
            Publish-SNSMessage -TopicArn $snsArn -Message $message -MessageAttributes @{"AWS.SNS.SMS.SenderID" = [Amazon.SimpleNotificationService.Model.MessageAttributeValue]$senderAttribute}
            $result.AlertsGenerated++
        }
    }
    else {
        write-host -ForegroundColor DarkGray $message
    }

    $result.DaysProcessed++
}

$storeHours = Load-StoreData
foreach ($storeHour in $storeHours) {
    Test-OpenHours $storeHour
}
$result | Add-Member -MemberType NoteProperty -Name Message -Value ("Opening hours successfully processed.")

# return result
$result
