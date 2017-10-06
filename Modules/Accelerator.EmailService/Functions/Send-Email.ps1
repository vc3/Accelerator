function Send-Email {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$From,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string[]]$To,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$false)]
        [string[]]$CC,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$false)]
        [string[]]$Bcc,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$Subject,

        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$Body,

        [Parameter(Mandatory=$false)]
        [switch]$BodyAsHtml,

        [Parameter(Mandatory=$false)]
        [string[]]$Attachments,

        [Parameter(Mandatory=$true, ParameterSetName='MailgunProvided')]
        [string]$MailgunDomain,

        [Parameter(ParameterSetName='MailgunProvided')]
        [SecureString]$MailgunApiKey,

        [Parameter(Mandatory=$true, ParameterSetName='Office365Provided')]
        [string]$Office365EmailAddress,

        [Parameter(ParameterSetName='Office365Provided')]
        [SecureString]$Office365Password,

        [Alias('Provider')]
        [ValidateSet('Mailgun', 'Office365')]
        [Parameter(ParameterSetName='Default')]
        [Parameter(ParameterSetName='NonInteractive')]
        [string]$ProviderName,

        [Alias('Connection')]
        [string]$ConnectionVariableName = 'EMAIL_CONNECTION',

        [switch]$PersistCredentials,

        [Parameter(Mandatory=$true, ParameterSetName='NonInteractive')]
        [switch]$NonInteractive
    )

    $connectionParams = @{
        'Connection' = $ConnectionVariableName
    }

    if ($PersistCredentials.IsPresent) {
        $connectionParams['PersistCredentials'] = $true
    }

    if ($NonInteractive.IsPresent) {
        $connectionParams['NonInteractive'] = $true
    }

    if ($PSCmdlet.ParameterSetName -eq 'MailgunProvided') {
        $connectionParams['MailgunDomain'] = $MailgunDomain
        if ($MailgunApiKey -and $MailgunApiKey.Length -gt 0) {
            $connectionParams['MailgunApiKey'] = $MailgunApiKey
        }
    } elseif ($PSCmdlet.ParameterSetName -eq 'Office365Provided') {
        $connectionParams['Office365EmailAddress'] = $Office365EmailAddress
        if ($Office365Password -and $Office365Password.Length -gt 0) {
            $connectionParams['Office365Password'] = $Office365Password
        }
    } elseif ($ProviderName) {
        $connectionParams['Provider'] = $ProviderName
    }

    $Connection = Connect-EmailService @connectionParams

    if ($Connection) {
        $enableSsl = $false

        if ($Connection.Provider -eq 'Mailgun') {
            Write-Verbose "Sending email with provider 'Mailgun'."
            $smtpCredential = New-Object 'PSCredential' @($Connection.SmtpLogin, $Connection.SmtpPassword)
            $smtpServer = 'smtp.mailgun.org'
        } elseif ($Connection.Provider -eq 'Office365') {
            Write-Verbose "Sending email with provider 'Office365'."
            $smtpCredential = New-Object 'PSCredential' @($Connection.EmailAddress, $Connection.Password)
            $enableSsl = $true
            $smtpServer = 'smtp.office365.com'
        } else {
            Write-Error "Unknown provider '$($Connection.Provider)'."
        }

        $sendMailArgs = @{
            'From' = $From
            'To' = $To
            'Subject' = $Subject
            'Body' = $Body
            'BodyAsHtml' = $BodyAsHtml.IsPresent
            'SmtpServer' = $smtpServer
            'Port' = 587
            'Credential' = $smtpCredential
        }
        
        if ($enableSsl) {
            $sendMailArgs['UseSSL'] = $true
        }

        if ($Bcc) {
          $sendMailArgs['BCC'] = $Bcc
        }
        
        if ($CC) {
          $sendMailArgs['CC'] = $cc
        }
        
        if ($Attachments -and $Attachments.Count -gt 0) {
            $sendMailArgs['Attachments'] = $Attachments
        }
        
        Send-MailMessage @sendMailArgs
    } else {
        Write-Error "Unable to connect to an email provider."
        return
    }
}
