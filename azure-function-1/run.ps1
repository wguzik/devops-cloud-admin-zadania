using namespace System.Net


param($Request, $TriggerMetadata)

$url = $Request.Query.Url
if (-not $url) {
    $url = $Request.Body.Url
}
$response = Invoke-WebRequest -Uri $url
$htmlContent = $response.Content

$titlePattern = "<title>(.*?)<\/title>"
$pageTitle = [regex]::Match($htmlContent, $titlePattern).Groups[1].Value
Write-Host "Page Title: $pageTitle"

$HttpStatus = @{
    PageStatus = $response.StatusCode
    StatusDescription = $response.StatusDescription
}

$date = get-date -Format "yyyy-MM-dd-HH:mm"

$scrapData = @{
    Date = $date 
    "params" = @{
    PageUrl = $url
    PageTitle = $pageTitle
    HttpStatus = $HttpStatus
    }
}

$jsonRepresentation = $scrapData | ConvertTo-Json -Depth 100

if ($url) {
    $body = "Requested $url was checked."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})

Push-OutputBinding -Name outputBlob -Value $jsonRepresentation