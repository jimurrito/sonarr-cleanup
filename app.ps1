<#
.SYNOPSIS
    Cleans up stuck downloads.
    Specifically downloads that do not contain a media file or contain potential viruses.

.DESCRIPTION
    Identifies downloads in Sonarr's queue that are completed but stuck in an
    "importPending" warning state — typically caused by no eligible files or
    dangerous content flags. Removes and blocklists each offending item, then
    triggers a new search.

.PARAMETER Url
    The base URL of your Sonarr instance (e.g. http://localhost:8989).

.PARAMETER ApiKeyPath
    Path to a file containing your Sonarr API key.

.EXAMPLE
    .\sonarr-script.ps1 -Url "http://192.168.1.10:8989" -ApiKeyPath "C:\secrets\sonarr.key"

.NOTES
    Author      : Jimurrito
    Version     : 1.0.0
    Requires    : PowerShell 5.1+, Sonarr v3
    Permissions : API key must have read/write queue access in Sonarr.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [Parameter(Mandatory=$true)]
    [string]$ApiKeyPath
)

write-host "Startup [$(get-date)]"

$key = get-content $ApiKeyPath -ErrorAction stop

$headers = @{
    "X-Api-Key" = $key
}

# Gathers all the download items in the queue
$queue = invoke-webrequest -uri "$Url/api/v3/queue" -Method 'GET' -Headers $headers | convertfrom-json | select-object records

# filter out the good bois and only keep the bad ones :p
$queue.records
| where-object {
    $_.status -eq "completed" `
        -and $_.trackedDownloadStatus -eq "warning" `
        -and $_.trackedDownloadState -eq "importPending" `
        -and $_.statusMessages.messages -match "No files found are eligible for import in" `
        -or $_.statusMessages.messages -match "Dangerous" `
        -or $_.statusMessages.messages -match "executable"
}
| foreach-object {
    # verbose
    write-host ("Bad download: [ {0} ] | [ {1} ]" -f $_.title, $_.statusMessages.messages)
    # delete & blacklist+search
    $uri = ("{0}/api/v3/queue/{1}?removeFromClient=true&blocklist=true" -f $Url, $_.id)
    $resp = invoke-webrequest -uri $uri -Method DELETE -Headers $headers
    # back at is again with the verbose!!
    write-host "Removed with status code: [$($resp.statusCode)]"
}

write-host "All done! [$(get-date)]"
