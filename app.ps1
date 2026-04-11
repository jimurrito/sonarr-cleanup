#
# Script to remove zombie programs from Sonarr
#

param(
  [Parameter(Mandatory=$true)]
  [string]$url,

  [string]$apikey_path = "./key"
)


write-host "Startup [$(get-date)]"


$key = get-content $apikey_path -ErrorAction stop

$headers = @{
  "X-Api-Key" = $key
}

# Gathers all the download items in the queue
$queue = invoke-webrequest -uri "$url/api/v3/queue" -Method 'GET' -Headers $headers | convertfrom-json | select-object records

# filter out the good bois and only keep the bad ones :p
$queue.records  
	| where-object {$_.status -eq "completed" -and $_.trackedDownloadStatus -eq "warning" -and $_.trackedDownloadState -eq "importPending"} 
	| where-object {$_.statusMessages.messages -match "No files found are eligible for import in"}
	| foreach-object {
		# verbose
		write-host "Bad download: [$($_.title)]"
		# delete & blacklist+search
		$resp = invoke-webrequest -uri "$url/api/v3/queue/$($_.id)?removeFromClient=true&blocklist=true" -Method 'DELETE' -Headers $headers
		# back at is again with the verbose!!
		write-host "Removed with status code: [$($resp.statusCode)]"
	}

write-host "All done! [$(get-date)]"


