{
    "DaemonAuthenticationType":     "password",
    "DaemonAuthenticationPassword": "${tfe_password}",
    "TlsBootstrapType":             "server-path",
    "TlsBootstrapHostname":         "${hostname}.${domain}",
    "TlsBootstrapCert":             "/etc/letsencrypt/live/${hostname}.${domain}/fullchain.pem",
    "TlsBootstrapKey":              "/etc/letsencrypt/live/${hostname}.${domain}/privkey.pem",
    "BypassPreflightChecks":        true,
    "ImportSettingsFrom":           "/home/ubuntu/application-settings.json",
    "LicenseFileLocation":          "/home/ubuntu/license.rli"
}
