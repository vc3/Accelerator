function Invoke-ApiRequest {
    [CmdletBinding()]
    param(
        [string]$Path,

        [Alias('Username')]
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Domain,

        [Alias('Password')]
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [SecureString]$ApiKey
    )

    $basicauth = ConvertTo-BasicAuth -Username 'api' -Password $ApiKey

    # https://documentation.mailgun.com/en/latest/api-intro.html#base-url
    $baseUrl = 'https://api.mailgun.net/v3'

    if ($Path) {
        $url = "$($baseUrl)/domains/$($Domain)/$($Path)"
    } else {
        $url = "$($baseUrl)/domains/$($Domain)"
    }

    Write-Verbose "Sending request to url '$($url)'."

    # https://social.technet.microsoft.com/Forums/scriptcenter/en-US/64c74e89-610e-4229-a56b-12f973232a0a/replace-invokerestmethod-in-powershell-20?forum=ITCG
    $request = [System.Net.WebRequest]::Create($url)
    $request.Accept = 'application/json'
    $request.Headers.Add('Authorization', "Basic $basicauth")

    # http://stackoverflow.com/a/4700154/170990
    try
    {
        $response = $request.GetResponse()
        $responseStatusCode = $response.StatusCode
    }
    catch
    {
        Write-Host "ERROR: [$($_.Exception.InnerException.GetType().FullName)] $($_.Exception.InnerException.Message)" -ForegroundColor Red
        $responseStatusCode = $_.Exception.InnerException.Response.StatusCode
    }

    if ($response) {
        $responseStream = $response.GetResponseStream()
        $responseStreamReader = New-Object System.IO.StreamReader $responseStream
        $responseData = $responseStreamReader.ReadToEnd()

        Write-Verbose "Response: $responseData"

        # http://stackoverflow.com/a/17602226/170990
        if (Get-Command 'ConvertFrom-Json' -ErrorAction SilentlyContinue) {
            $responseObj = ConvertFrom-Json $responseData
        } else {
            # 'ConvertFrom-Json' is not defined in PSv2
            [System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
            $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
            $responseObj = New-Object PSObject -Property $serializer.DeserializeObject($responseData)
        }
        
        return $responseObj
    } elseif ($responseStatusCode -eq 'Unauthorized') {
        Write-Host "ERROR: API key is invalid." -ForegroundColor Red
        return
    } else {
        Write-Error "Unknown error (code=$($responseStatusCode))."
        return
    }
}
