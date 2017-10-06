function Connect-EmailService {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param(
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

        [Parameter(ParameterSetName='Default')]
        [switch]$Force,

        [Parameter(Mandatory=$true, ParameterSetName='NonInteractive')]
        [switch]$NonInteractive
    )

    if ($NonInteractive.IsPresent) {
        $interactive = $false
    } elseif (Test-IsNonInteractiveShell) {
        Write-Warning "The command appears to be running in a non-interactive session."
        Write-Information "Please explicitly pass '-NonInteractive' if possible."
        $interactive = $false
    } else {
        $interactive = $true
    }

    $ConnectionVariable = Get-Variable -Name $ConnectionVariableName -Scope "Global" -EA 0
    if ($ConnectionVariable) {
        $Connection = $ConnectionVariable.Value
    } else {
        $Connection = $null
    }

    $defaultProviderConfig = Get-Config 'EmailService.DefaultProvider'

    if ($PSCmdlet.ParameterSetName -eq 'MailgunProvided') {
        $provider = 'Mailgun'
    } elseif ($PSCmdlet.ParameterSetName -eq 'Office365Provided') {
        $provider = 'Office365'
    } else {
        if ($ProviderName) {
            $provider = $ProviderName
        } elseif (-not($interactive)) {
            if ($Force) {
                Write-Error "The provider must be specified to force a re-connection."
                return
            } elseif ($Connection -and $Connection.Provider -eq 'Office365') {
                $provider = 'Office365'
            } elseif ($Connection -and $Connection.Provider -eq 'Mailgun') {
                $provider = 'Mailgun'
            } else {
                if ($defaultProviderConfig -and $defaultProviderConfig.Value) {
                    $provider = $defaultProviderConfig.Value
                } else {
                    Write-Error "Unable to determine the email provider to use."
                    return
                }
            }
        } else {
            $provider = $null
            $providerAttempts = 0

            while (-not($provider) -and $providerAttempts -lt 3) {
                if ($providerAttempts -eq 0) {
                    Write-Host "Please enter the email provider to use (options are Mailgun, and Office365)."
                    if (-not($Force) -and $defaultProviderConfig -and $defaultProviderConfig.Value) {
                        Write-Host "HINT: Press ENTER to use the default provider '$($defaultProviderConfig.Value)'."
                    }
                }

                $provider = Read-Host "Provider (Mailgun | Office365)"

                $providerAttempts += 1

                if ($provider) {
                    if (-not(@('Mailgun', 'Office365') -contains $provider)) {
                        Write-Warning "Invalid selection '$($provider)'."
                        $provider = $null
                    }
                } elseif (-not($Force)) {
                    if ($Connection -and $Connection.Provider -eq 'Office365') {
                        $provider = 'Office365'
                    } elseif ($Connection -and $Connection.Provider -eq 'Mailgun') {
                        $provider = 'Mailgun'
                    } elseif ($defaultProviderConfig -and $defaultProviderConfig.Value) {
                        $provider = $defaultProviderConfig.Value
                    }
                }
            }

            if (-not($provider)) {
                Write-Error "Unable to get a valid selection for parameter '-Provider'."
                return
            }
        }

        if (-not($Force)) {
            if ($provider -eq 'Office365' -and $Connection -and $Connection.Provider -eq 'Office365') {
                $Office365EmailAddress = $Connection.EmailAddress
                $Office365Password = $Connection.Password
            } elseif ($provider -eq 'Mailgun' -and $Connection -and $Connection.Provider -eq 'Mailgun') {
                $MailgunDomain = $Connection.Domain
                $MailgunApiKey = $Connection.ApiKey
            }
        }
    }

    $Connection = $null

    if (Get-Variable -Name $ConnectionVariableName -Scope "Global" -EA 0) {
        Write-Verbose "Removing variable '$($ConnectionVariableName)'."
        Remove-Variable -Name $ConnectionVariableName -Scope "Global"
    }

    if ($provider -eq 'Mailgun') {
        if (-not(Get-Module 'Mailgun' -EA 0)) {
            Import-Module "$($PSScriptRoot)\..\Modules\Mailgun\Mailgun.psm1"
        }

        $mailgunDomainConfig = Get-Config 'Mailgun.Domain'

        if (-not($MailgunDomain)) {
            if (-not($interactive)) {
                if ($mailgunDomainConfig -and $mailgunDomainConfig.Value) {
                    $MailgunDomain = $mailgunDomainConfig.Value
                } else {
                    Write-Error "Parameter 'MailgunDomain' is required."
                    return
                }
            } else {
                $domainAttempts = 0

                while (-not($MailgunDomain) -and $domainAttempts -lt 3) {
                    if ($domainAttempts -eq 0) {
                        Write-Host "Please enter the Mailgun domain."
                        if ($defaultProviderConfig -and $defaultProviderConfig.Value) {
                            Write-Host "HINT: Press ENTER to use the default domain '$($mailgunDomainConfig.Value)'."
                        }
                    }

                    $MailgunDomain = Read-Host "Mailgun Domain"

                    if (-not($MailgunDomain)) {
                        if ($mailgunDomainConfig -and $mailgunDomainConfig.Value) {
                            $MailgunDomain = $mailgunDomainConfig.Value
                        }
                    }

                    $domainAttempts += 1
                }

                if (-not($MailgunDomain)) {
                    Write-Error "Mailgun domain is required."
                    return
                }
            }
        }

        if (-not($interactive)) {
            $prompts = $null
        } else {
            $prompts = @{
                Message="Mailgun API Key (i.e. `"key-*`")"
                DefaultUsername='api'
                UseDialog = $true
                Username='Domain'
                Password='API Key'
            }
        }

        Connect-Service -Service $MailgunDomain -Username 'api' -Password $MailgunApiKey -PersistCredentials:$PersistCredentials -Prompts $prompts -UseCredential {
            $cred = $Args[0]

            Write-Verbose "Attempting to validate connection to mailgun domain '$($MailgunDomain)'."

            $responseObj = Mailgun\Invoke-ApiRequest -Domain $MailgunDomain -ApiKey $cred.Password

            if ($responseObj.domain) {
                Write-Verbose "Connection succeeded."
                $conn = New-Object 'PSObject'
                $conn | Add-Member -Type 'NoteProperty' -Name 'Provider' -Value 'Mailgun'
                $conn | Add-Member -Type 'NoteProperty' -Name 'Domain' -Value $MailgunDomain
                $conn | Add-Member -Type 'NoteProperty' -Name 'ApiKey' -Value $cred.Password
                $conn | Add-Member -Type 'NoteProperty' -Name 'RequireTls' -Value $responseObj.domain.require_tls
                $conn | Add-Member -Type 'NoteProperty' -Name 'SmtpLogin' -Value $responseObj.domain.smtp_login
                $conn | Add-Member -Type 'NoteProperty' -Name 'SmtpPassword' -Value ($responseObj.domain.smtp_password | ConvertTo-SecureString -AsPlainText -Force)
                Set-Variable -Name $ConnectionVariableName -Value $conn -Scope 'Global'
                return $true
            } else {
                Write-Verbose "Connection failed: unexpected response object."
                return $false
            }
        }
    } elseif ($provider -eq 'Office365') {
        if (-not(Get-Module 'MSOnline' -EA 0)) {
            Import-Module "$($PSScriptRoot)\..\Modules\MSOnline\1.0\MSOnline.psd1"
        }

        if (-not($interactive)) {
            $prompts = $null
        } else {
            $prompts = @{
                Message="Office 365 Login";
                Hint="Use your Office 365 email and password.";
                UseDialog = $true
                DefaultUsername = $Office365EmailAddress
                Username="Email";
                Password="Password"
            }
        }

        Connect-Service -Service 'smtp.office365.com' -Username $Office365EmailAddress -Password $Office365Password -PersistCredentials:$PersistCredentials -Prompts $prompts -UseCredential {
            $cred = $Args[0]

            Write-Verbose "Attempting to validate Office 365 login for user '$($cred.Username)'."

            try {
                Connect-MsolService -Credential $cred -ErrorAction 'Stop'
                $conn = New-Object 'PSObject'
                $conn | Add-Member -Type 'NoteProperty' -Name 'Provider' -Value 'Office365'
                $conn | Add-Member -Type 'NoteProperty' -Name 'EmailAddress' -Value $cred.Username
                $conn | Add-Member -Type 'NoteProperty' -Name 'Password' -Value $cred.Password
                Set-Variable -Name $ConnectionVariableName -Value $conn -Scope 'Global'
                return $true
            } catch {
                Write-Warning "$($_.Exception.Message)"
                return $false
            }
        }
    } else {
        Write-Error "Unsupported provider '$($provider)'."
        return
    }

    $ConnectionVariable = Get-Variable -Name $ConnectionVariableName -Scope "Global" -EA 0
    if ($ConnectionVariable) {
        $Connection = $ConnectionVariable.Value
        return $Connection
    } else {
        Write-Error "Unable to connect to provider '$($provider)'."
    }
}
