$config = (Get-Content -Path ("{0}/conf.json" -f $PSScriptRoot) | ConvertFrom-Json)

$CertPath   = $config.certPath
$CertKey    = $CertPath + 'key.pem'
$CertPublic = $CertPath + 'cert.pem'
$CertMerge  = $CertPath + 'merged.pfx'
$CertPass   = $config.certPass
$CertExpire = 365
$CertName   = $config.certName

openssl req -newkey rsa:2048 -new -nodes -x509 -days $CertExpire -keyout $CertKey -out $CertPublic -subj "/CN=$CertName"
openssl pkcs12 -in $CertPublic -inkey $CertKey -export -out $CertMerge -passout pass:$CertPass