
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

    $content += ("From: {0}`n" -f $from.Address)
    $content += ("To: {0}`n" -f $to.Address)
    $content += ("Subject: {0}`n" -f $subject)

    $content += $body

    return $content
}
