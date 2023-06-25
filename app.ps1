
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

# ERROR Messages
# case response.code.to_i
#       when 403
#         warn "Request was denied by your Redmine server. " +
#              "Make sure that 'WS for incoming emails' is enabled in application settings and that you provided the correct API key."
#         return 77
#       when 422
#         warn "Request was denied by your Redmine server. " +
#              "Possible reasons: email is sent from an invalid email address or is missing some information."
#         return 77
#       when 400..499
#         warn "Request was denied by your Redmine server (#{response.code})."
#         return 77
#       when 500..599
#         warn "Failed to contact your Redmine server (#{response.code})."
#         return 75
#       when 201
#         debug "Processed successfully"
#         return 0
#       else
#         return 1

