function Connect-Service {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$Service,

		[string]$Username,

		[SecureString]$Password,

		[switch]$PersistCredentials,

		[ValidateSet('None', 'CredentialManager', 'CredentialFile')]
		[string]$StorageTarget,

		[PSObject]$Prompts,

		[Parameter(Mandatory=$true)]
		[ScriptBlock]$UseCredential
	)

	$tries = 0
	$valid = $false

	if ($StorageTarget -eq 'CredentialManager') {
        Write-Verbose "Using credential storage target '$($StorageTarget)'."
		if (-not(Get-Module 'CredentialManager' -EA 0)) {
			Write-Error "Module 'CredentialManager' is not loaded."
		}
	} elseif ($StorageTarget -eq 'CredentialFile') {
        Write-Verbose "Using credential storage target '$($StorageTarget)'."
	} elseif ($StorageTarget -eq 'None') {
        if ($PersistCredentials.IsPresent) {
          Write-Warning "Cannot persist credentials when preference value for StorageTarget='$($StorageTarget)'."
        }
    } elseif ($StorageTarget) {
		Write-Warning "Unexpected value for StorageTarget='$($StorageTarget)'."
	} else {
		$StorageTarget = 'CredentialManager'
        Write-Verbose "Using default credential storage target '$($StorageTarget)'."
		if (-not(Get-Module 'CredentialManager' -EA 0)) {
			Write-Error "Module 'CredentialManager' is not loaded."
		}
	}

	do {
		$cred = $null

		# Acquire credential object
		if ($tries -eq 0) {
			if($Password -and $Password.Length -gt 0) {
				Write-Verbose "Attempting to use provided password."
			} else {
                if ($StorageTarget -eq 'CredentialManager') {
					Write-Verbose "Searching for credentials in the credential manager."
    				try {
    					# Read creds from Windows credential store if not passed in
    					$cred = Get-StoredCredential -Target $Service
    					if ($cred -and $Username -and $cred.Username -ne $Username) {
    						if ($PersistCredentials.IsPresent) {
    							Remove-StoredCredential -Target $Service | Out-Null
    						}
    						$cred = $null
    					}
    				} catch {
                        # Ignore errors...
    				}
                } elseif ($StorageTarget -eq 'CredentialFile') {
					Write-Verbose "Searching for credentials in a credential file."
                    try {
                        $cred = Get-SavedCredential -Target $Service -Username $Username
                    } catch {
                        # Ignore errors...
                    }
                } else {
					Write-Verbose "Unable to get stored credentials from target '$($StorageTarget)'."
				}
			}

			if (-not($cred) -and $Username -and ($Password -and $Password.Length -gt 0)) {
				Write-Verbose "Creating credential object from provided username and password."
				$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username,$Password
			}
		}

		# If there's still not a credential, attempt to prompt
		if (-not($cred)) {
			if($Prompts) {
				# Prompt user if no creds we saved nor passed in
				if ($Prompts.UseDialog) {
					Write-Verbose "Prompting for credentials using dialog."
					$credType = 'Generic'
					if ($Prompts.CredType) {
						$credType = $Prompts.CredType
					}
					$cred = $Host.UI.PromptForCredential($Prompts.Message, "$(if ($Prompts.Hint) { 'HINT: ' + $Prompts.Hint })", $Prompts.DefaultUsername, $null, $credType, 'Default')
					$cred | Add-Member -Type 'NoteProperty' -Name 'PSUserPrompt' -Value 'PromptForCredentials'

					$Username = $cred.Username
					if ($Username.StartsWith('\')) {
						Write-Verbose "Fixing username '$($Username)'..."
						$Username = $Username.Substring(1)
					}

					$Password = $cred.Password
				} else {
					Write-Verbose "Prompting for credentials using host."

					if (-not($Prompts.Password)) {
						Write-Error "Prompt object 'Password' property is required."
						return
					}

					Write-Host ""

					if($Prompts.Message) {
						Write-Host ("Enter " + $Prompts.Message)
					}

					if ($Prompts.Hint) {
						Write-Host ("HINT: " + $Prompts.Hint)
					}

					if($Prompts.Username) {
						if ($Prompts.DefaultUsername) {
							$Username = Read-Host "$($Prompts.Username) (press ENTER to use '$($Prompts.DefaultUsername)')"
							if (-not($Username)) {
								$Username = $Prompts.DefaultUsername
							}
						} else {
							$Username = Read-Host $Prompts.Username
						}
					} elseif ($Prompts.DefaultUsername) {
						$Username = $Prompts.DefaultUsername
					}

					$Password = Read-Host $Prompts.Password -AsSecureString

					if ($Username -and ($Password -and $Password.Length -gt 0)) {
						$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username,$Password
						$cred | Add-Member -Type 'NoteProperty' -Name 'PSUserPrompt' -Value 'Read-Host'
					}

					Write-Host ""
				}
			} else {
				Write-Verbose "No prompt information was specified."
			}

			if (-not($cred)) {
				# Dont have a valid credential so stop
				Write-Verbose "Unable to prompt for credentials."
				break
			}
		}

		if ($cred) {
			Write-Verbose "Passing credential $($cred) to script block for testing and/or use."

			# There's now a credential so attempt to use it
			$valid = & $UseCredential $cred

			if ($valid) {
				$Username = $cred.Username
				$Password = $cred.Password
			} else {
				Write-Host
				Write-Host "Sorry, credentials are not valid!"
				Write-Host
			}
		} else {
			$valid = $false
		}

	} while((-not $valid) -and (++$tries -le 3))

	# Done with reties. Was the usage successful?
	if (-not $valid) {
		if ($prompt) {
			Write-Error "Sorry, credentials for '$($Service)' are not valid!"
		} else {
			Write-Error "Sorry, credentials for '$($Service)' were not found."
		}
		return
	}

	# Save valid credentials into Windows credential store if needed
	if ($PersistCredentials.IsPresent) {
		if ($Username -and ($Password -and $Password.Length -gt 0)) {
			if ($StorageTarget -eq 'CredentialManager') {
				Write-Verbose "Storing credentials to service '$($Service)' for user '$($Username)' in the credential manager."
				New-StoredCredential -Target $Service -Username $Username -SecurePassword $Password -persist 'Enterprise' | out-null
			} elseif ($StorageTarget -eq 'CredentialFile') {
				Write-Verbose "Storing credentials to service '$($Service)' for user '$($Username)' in a credential file."
				New-SavedCredential -Target $Service -Username $Username -Password $Password | Out-Null
			} else {
				Write-Warning "Unknown credential storage target '$($StorageTarget)'."
			}
		} else {
			Write-Warning "Unable to persist credentials."
		}
	}
}
