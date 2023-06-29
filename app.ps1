


function Get-FormatedEmailForHandler {
    param (
        [Parameter(Mandatory = $true)]
        [mailaddress]$from,
        [Parameter(Mandatory = $true)]
        [mailaddress]$to,
        [Parameter(Mandatory = $true)]
        [string]$subject,
        [Parameter(Mandatory = $true)]
        [string]$body
    )
    
    $content = ""
    
    $content += ("From: {0}$LF" -f $from.Address)
    $content += ("To: {0}$LF" -f $to.Address)
    $content += ("Subject: {0}$LF" -f $subject)
    $content += "$LF"

 
    ForEach ($line in $((Convert-HtmlToPlainText -Html $body) -split "$LF")) {
        if ([string]::IsNullOrEmpty($line)) {
            continue;
        }

        $content += "$line $LF"
    }
    return $content
}

function Get-Thumbprint {
    param (
        $StoreName,
        $CertMerge,
        $CertPass
    )

    # Store certificate in certificate store
    $StoreName = [System.Security.Cryptography.X509Certificates.StoreName]::My 
    $StoreLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    $Store = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $StoreLocation) 
    $Flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertMerge, $CertPass, $Flag)
    $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $Store.Add($Certificate)
    $Store.Close() 

    # Get cert thumbprint
    $CertValue = [Convert]::ToBase64String($Certificate.GetRawCertData())
    return  $Certificate.Thumbprint
}

function Convert-HtmlToPlainText {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Html
    )

    Write-Output $([System.Web.HttpUtility]::HtmlDecode($Html) -replace '<br>', $LF -replace '<hr[^>]+>', "$LF-----Original Message-----$LF" -replace '<[^>]+>', '')
}

$LF = "`r`n";
if (-not (Test-Path -Path ("{0}/logs" -f $PSScriptRoot) -PathType Container)) {
    New-Item -Path ("{0}/logs" -f $PSScriptRoot) -ItemType Directory
}

$LogPath = ('{0}/logs/log_{1}.log' -f $PSScriptRoot, (Get-Date -Format "ddMMyyyy"))
Add-Content -Value ("BOOT: {0}" -f (Get-Date -Format "HH:mm")) -Path $LogPath 
Write-Host ("BOOT: {0}" -f (Get-Date -Format "HH:mm"))

if (Get-Module -ListAvailable -Name Microsoft.Graph.Mail) {
    Add-Content -Value "Modules Found!" -Path $LogPath 
    Write-Host "Module exists"
} 
else {
    Add-Content -Value "Modules not Found!" -Path $LogPath 
    Install-Module "Microsoft.Graph.Mail" -RequiredVersion 1.24.0 -Force
    Install-Module "Microsoft.Graph.Users.Actions" -RequiredVersion 1.24.0 -Force
}

Import-Module Microsoft.Graph.Mail -RequiredVersion 1.24.0 
Import-Module Microsoft.Graph.Users.Actions -RequiredVersion 1.24.0 

if (-not (Test-Path -Path ("{0}/conf.json" -f $PSScriptRoot))) {
    throw "Config File not found";
    exit;
}

$config = (Get-Content -Path ("{0}/conf.json" -f $PSScriptRoot) | ConvertFrom-Json)

try {
    Connect-MgGraph -TenantId $config.azureTenantID -ClientId $config.azureAppID -CertificateThumbprint $(Get-Thumbprint -CertMerge  ("{0}merged.pfx" -f $config.certPath) -StoreName $config.certName -CertPass $config.certPass)
    Add-Content -Value "Connected to MS Graph API" -Path $LogPath 
}
catch {
    throw "Unable to authenticate";
    Add-Content -Value "Unable to authenticate to MS Graph API" -Path $LogPath 
    exit;
}

if (-not (Test-Path -Path ("{0}/temp" -f $PSScriptRoot) -PathType Container)) {
    New-Item -ItemType Directory -Path ("{0}/temp" -f $PSScriptRoot) | Out-Null
}
Remove-Item -Path ('{0}/temp/*' -f $PSScriptRoot)

$EmailFolders = Get-MgUserMailFolder -UserId $config.redmineMailAddress -Top 100
$sourceFolderID = ($EmailFolders | Where-Object -Property 'DisplayName' -value 'Inbox' -EQ).Id
$notParsedFolderID = ($EmailFolders | Where-Object -Property 'DisplayName' -value 'failed' -EQ).Id
$ParsedFolderID = ($EmailFolders | Where-Object -Property 'DisplayName' -value 'read' -EQ).Id
$ErrorFolderID = ($EmailFolders | Where-Object -Property 'DisplayName' -value 'error' -EQ).Id

$isInError = $false
while ($isInError -eq $false) {
    $Emails = Get-MgUserMailFolderMessage -UserId $config.redmineMailAddress -MailFolderId $sourceFolderID -Filter "IsRead eq false" -Property Subject, Body, From
    foreach ($Email in $Emails) {  
        #tEMPORARY DEV FILTER
        if ($Email.Subject -notlike "*#8899*" ) {
            continue;
        }

        $RedmineIssueID = [regex]::Match($Email.Subject, "(?<=\#).+?(?=\])").Value
        if ([string]::IsNullOrEmpty($RedmineIssueID)) {
            Move-MgUserMessage -UserId $config.redmineMailAddress -MessageId $Email.Id -DestinationId $ErrorFolderID
            Add-Content -Value ("Unable to pase Eamil with subject: {0}" -f $Email.Subject) -Path $LogPath 
            continue;
        }

        $MimeMessagePath = ('{0}/temp/{1}' -f $PSScriptRoot, $Email.Id)
        try {
            Get-MgUserMessageContent -UserId $config.redmineMailAddress -MessageId $Email.Id -OutFile $MimeMessagePath
            
            $Headers = @{ 
                'User-Agent' = 'Redmine mail handler/0.2.3' 
            }

            $Form = @{
                key   = $config.redmineWSKey
                email = (Get-Content -Path $MimeMessagePath -Raw)
            }

            $req = Invoke-WebRequest -Uri ('{0}/mail_handler/' -f $config.redmineRootUrl) -Method POST -Headers $Headers -Form $Form
                
            if ($req.StatusCode -ne 200 -and $req.StatusCode -ne 201) {
                Move-MgUserMessage -UserId $config.redmineMailAddress -MessageId $Email.Id -DestinationId $notParsedFolderID
                Add-Content -Value ("Unable to pase Eamil with subject: {0}" -f $Email.Subject) -Path $LogPath 
                throw "error"
            }
                
            write-host ("FROM: {0}" -f $Email.From.EmailAddress.Address)
            write-host ("SUBJECT: {0}" -f $Email.Subject)
            if (-not [string]::IsNullOrEmpty($Email.BodyPreview)) {
                write-host ("SUBJECT: {0}" -f $Email.BodyPreview)
            }   

            Move-MgUserMessage -UserId $config.redmineMailAddress -MessageId $Email.Id -DestinationId $ParsedFolderID
        }
        catch {
            write-host "error" + $_
            Add-Content -Value $_ -Path $LogPath 
            $isInError = $true
        }
        finally {
            if (Test-Path -Path $MimeMessagePath) {
                Remove-Item -Path $MimeMessagePath
            }
        }
    }

    if ($isInError -ne $true) {
        write-host ("Sleeping for {0}s" -f $config.syncIntervalSeconds)
        Start-Sleep -Seconds $config.syncIntervalSeconds
    }
}