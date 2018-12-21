# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2018 Jacob Keller. All rights reserved.

# Terminate on all errors...
$ErrorActionPreference = "Stop"

# Load the shared module
Import-Module -Force -DisableNameChecking (Join-Path -Path $PSScriptRoot -ChildPath l0g-101086.psm1)

# See l0g-101086.psm1 for descriptions of each configuration field
$RequiredParameters = @(
    "extra_upload_data"
    "restsharp_path"
    "simple_arc_parse_path"
    "last_upload_file"
    "arcdps_logs"
    "upload_log_file"
    "guilds"
)

# Load the configuration from the default file (version 2)
$config = Load-Configuration "l0g-101086-config.json" 2 $RequiredParameters
if (-not $config) {
    exit
}

# Load relevant configuration variables
$last_upload_file = $config.last_upload_file
$arcdps_logs = $config.arcdps_logs

if (-not $config.debug_mode) {
    Set-Logfile $config.upload_log_file
}

# Simple storage format for extra ancillary data about uploaded files
$extra_upload_data = $config.extra_upload_data
$simple_arc_parse = $config.simple_arc_parse_path

# Determine what generator to use
$valid_generators = @( "rh", "ei" )
$dps_report_generator = $config.dps_report_generator.Trim()
if ($dps_report_generator -and -not $valid_generators.Contains($dps_report_generator)) {
    Read-Host -Prompt "The dps.report generator $dps_report_generator is unknown..."
    exit
}

# Make sure RestSharp.dll exists
if (-not (X-Test-Path $config.restsharp_path)) {
    Read-Host -Prompt "The RestSharp.dll is expected to be located at '$($config.restsharp_path)', but doesn't appear to exist. Please download RestSharp.dll and update the configuration. Press enter to exit"
    exit
}

# Make sure that simpleArcParse has been correctly generated
if (-not (X-Test-Path $simple_arc_parse)) {
    Read-Host -Prompt "simpleArcParse is expected to be located at '${simple_arc_parse}', but doesn't appear to exist. Please download simpleArcParse and update the configuration. Press enter to exit"
    exit
}

# Make sure that the arcdps_logs folder exists
if (-not (X-Test-Path $arcdps_logs)) {
    Read-Host -Prompt "The arcdps.cbtlogs folder is expected to be located at '${arcdps_logs}', but doesn't appear to exist. Please update the configuration. Press enter to exit."
    exit
}

# Require a gw2raidar token if gw2raidar uploading is enabled
if ((-not $config.gw2raidar_token) -and ($config.upload_gw2raidar -ne "no")) {
    Read-Host -Prompt "Uploading to gw2raidar requires a gw2raidar authentication token. Press enter to exit"
    exit
}

# Require a dps.report token if dps.report uploading is enabled
if ((-not $config.dps_report_token) -and ($config.upload_dps_report -ne "no")) {
    Read-Host -Prompt "Uploading to dps.report requires an authentication token. Press enter to exit"
    exit
}

# Notify the user that they should remove the start map directory
if ($gw2raidar_start_map) {
    if (X-Test-Path $gw2raidar_start_map) {
        Log-Output "The gw2raidar_start_map directory and configuration variable are no longer necessary. It is now safe to remove them."
    } else {
        Log-Output "The gw2raidar_start_map configuration variable is no longer necessary, and is safe to remove."
    }
}

# Create the startmap directory if it doesn't exist
if (-not $extra_upload_data) {
    Read-Host -Prompt "A folder to hold extra upload data must be configured. Press enter to exit"
} elseif (-not (X-Test-Path $extra_upload_data)) {
    try {
        New-Item -ItemType directory -Path $extra_upload_data
    } catch {
        Write-Exception $_
        Read-Host -Prompt "Unable to create $extra_upload_data. Press enter to exit."
        exit
    }
}

# Make sure that simpleArcParse version matches our expectation
$simple_arc_version = (& $simple_arc_parse version)
if (-not (Check-SimpleArcParse-Version $simple_arc_version)) {
    Read-Host -Prompt "Press enter to exit"
    exit
}

Add-Type -Path $config.restsharp_path
Add-Type -AssemblyName "System.IO.Compression.FileSystem"

# Determine the most recent release of ArcDPS
$arcdps_headers = (Invoke-WebRequest -UseBasicParsing -Uri https://www.deltaconnected.com/arcdps/x64/d3d9.dll.md5sum).Headers
$arcdps_release_date = (Get-Date -Date ($arcdps_headers['Last-Modified'])).Date

# If we have a last upload file, we want to limit our scan to all files since
# the last time that we uploaded.
#
# This invocation is a bit complicated, but essentially we recurse through all folders within
# the $arcdps_logs directory and find all files which end in *.evtc.zip. We store them by the
# last write time, and then we return the full path of that file.
if (Test-Path $last_upload_file) {
    $last_upload_time = Get-Content -Raw -Path $last_upload_file | ConvertFrom-Json | Select-Object -ExpandProperty "DateTime" | Get-Date
    $files = @(Get-ChildItem -Recurse -File -LiteralPath $arcdps_logs | Where-Object { ( ExtensionIs-EVTC $_.Name ) -and $_.LastWriteTime -gt $last_upload_time} | Sort-Object -Property LastWriteTime | ForEach-Object {$_.FullName})
} else {
    $files = @(Get-ChildItem -Recurse -File -LiteralPath $arcdps_logs | Where-Object { ExtensionIs-EVTC $_.Name } | Sort-Object -Property LastWriteTime | ForEach-Object {$_.FullName})
}

$next_upload_time = Get-Date
Log-Output "~~~"
Log-Output "Uploading arcdps logs at $next_upload_time..."
Log-Output "~~~"

# Main loop to generate and upload gw2raidar and dps.report files
ForEach($f in $files) {
    $name = Get-UncompressedEVTC-Name $f
    Log-Output "---"
    Log-Output "Saving ancillary data for ${name}..."

    $dir = Join-Path -Path $extra_upload_data -ChildPath $name
    if (X-Test-Path $dir) {
        Log-Output "Ancillary data appears to have already been created"
        If (-not (Test-Path -PathType Container -Path $dir)) {
            Log-Output "Ancillary data path '$dir' is not a directory?"
            Log-Output "Please move or delete '$dir' and try again."
            Write-Output "Unable to process '$dir'. See log file for more details"
            Read-Host -Prompt "Press any key to exit..."
            exit
        }
        Log-Output "Overwriting..."
        Remove-Item -Recurse -Force $dir
    }

    # Make the ancillary data directory
    try {
        New-Item -ItemType Directory -Path $dir
    } catch {
        Write-Exception $_
        Log-Output "Unable to create extra upload directory '$dir'"
        Read-Host -Prompt "Unable to process ${f}... Press any key to exit..."
        exit
    }

    if (ExtensionIs-CompressedEVTC $f) {
        # simpleArcParse cannot deal with compressed data, so we must uncompress
        # it first, before passing the file to the simpleArcParse program
        [io.compression.zipfile]::ExtractToDirectory($f, $dir) | Out-Null
        $evtc = Join-Path -Path $dir -ChildPath $name

        # Sometimes the zip file stores the uncompressed file suffixed with .tmp
        if (-not (X-Test-Path $evtc)) {
            $evtc = Join-Path -Path $dir -ChildPath "${name}.tmp"
        }

        # Sometimes the zip file stores the uncompressed file without the .evtc
        if (-not (X-Test-Path $evtc)) {
            $evtc = Join-Path -Path $dir -ChildPath ([io.fileinfo]$name).basename
        }

        if (-not (X-Test-Path $evtc)) {
            throw "${evtc} is compressed, but does not appear to contain the correct contents"
        }
    } else {
        # if the file was not compressed originally, we don't need to copy it
        $evtc = $f
    }

    try {
        # Save the path to the original evtc file
        $f | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "evtc.json")

        # Parse the evtc header file and get the encounter name and id
        $evtc_header_data = (& $simple_arc_parse header "${evtc}")

        if ([string]::IsNullOrEmpty($evtc_header_data)) {
            throw "${evtc} is not recognized as a valid .evtc file by simpleArcParse."
        }

        $evtc_header = ($evtc_header_data.Split([Environment]::NewLine))

        # Parse the evtc file and extract account names
        $player_data = (& $simple_arc_parse players "${evtc}")
        if ([string]::IsNullOrEmpty($player_data)) {
            $players = @()
        } else {
            $players = $player_data.Split([Environment]::NewLine)
        }

        # Determine the ArcDPS release date of this encounter
        try {
            $evtc_arcdps_version = [DateTime]::ParseExact($evtc_header[0], 'EVTCyyyyMMdd', $null)

            # gw2raidar is extremely picky about uploading new encounters, and will generally
            # only parse the most recent release of ArcDPS. Warn the user if the version of
            # for this encounter is out of date. We'll still try to upload to gw2raidar, but
            # at least the user will be aware that the links may not be generated.
            if ($evtc_arcdps_version -lt $arcdps_release_date) {
                Log-Output "It appears that ${name} was recorded using an outdated ArcDPS version released on $(Get-Date -Format "MMM d, yyyy" $evtc_arcdps_version)"
                Log-Output "The most recent ArcDPS version was releasted on $(Get-Date -Format "MMM d, yyyy" $arcdps_release_date)"
                Log-Output "gw2raidar is unlikely to accept this encounter, so you might not see a link for it in the formatted encounters list"
                Log-Output "It is recommended that you update ArcDPS to avoid this issue."
            }
        } catch {
            Write-Exception $_
            Log-Output "Unable to determine the ArcDPS version used to record ${name}"
            Log-Output "EVTC ArcDPS version was '$evtc_arcdps_version'"
            Log-Output "EVTC header was '$evtc_header'"
            Log-Output "ArcDPS release date was '$arcdps_release_date'"
        }

        # Determine the guild to associate with this encounter
        $guild = Determine-Guild $config.guilds $players $evtc_header[2]
        if (-not $guild) {
            throw "No guilds matched this encounter"
        }

        $guild | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "guild.json")

        Log-Output "Guild: ${guild}"

        $players | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "accounts.json")

        $evtc_header[0] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "version.json")
        $evtc_header[1] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "encounter.json")
        $evtc_header[2] | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "id.json")

        Log-Output "EVTC Version: $(${evtc_header}[0])"
        Log-Output "Encounter: $(${evtc_header}[1])"
        Log-Output "ID: $(${evtc_header}[2])"

        # Parse the evtc combat events to determine SUCCESS/FAILURE status
        $evtc_success = (& $simple_arc_parse success "${evtc}")
        $evtc_success | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "success.json")

        Log-Output "Outcome: ${evtc_success}"

        # Extract the precise duration in milliseconds
        $precise_duration = (& $simple_arc_parse duration "${evtc}")
        $precise_duration | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "precise_duration.json")

        # Parse the evtc combat events to determine the server start time
        $start_time = (& $simple_arc_parse start_time "${evtc}")
        $start_time | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "servertime.json")

        Log-Output "Start Time: ${start_time}"

        # Parse the evtc to determine if the encounter was a challenge mote
        $is_cm = (& $simple_arc_parse is_cm "${evtc}")
        $is_cm | ConvertTo-Json | Out-File -FilePath (Join-Path $dir -ChildPath "is_cm.json")

        Log-Output "Challenge Mote: ${is_cm}"

    } catch {
        Write-Exception $_

        # Remove the extra data for this object
        Remove-Item -Path $dir -Recurse

        # If we failed to parse an encounter, it is likely due to either data corruption such as invalid
        # evtc files being generated, or because the evtc file format has changed. Stop processing immediately
        # so that the user can verify what is wrong, and intervene.
        Read-Host -Prompt "Unable to process ${f}... Press any key to exit..."
        exit
    } finally {
        # If the file was originally compressed, there's no need to keep around the uncompressed copy
        if ($f -ne $evtc -and (Test-Path $evtc)) {
            Remove-Item -Path $evtc
        }
    }

    # Determine if the encounter was successful or not
    $encounter_status = Get-Content -Raw -Path (Join-Path -Path $dir -ChildPath "success.json") | ConvertFrom-Json
    if ($encounter_status -eq "SUCCESS") {
        $success = $true
    } else {
        $success = $false
    }

    # Upload to gw2raidar (if configured) first, because the server processes in the background.
    try {
        Maybe-UploadTo-Gw2Raidar $config $f $guild $dir $success
    } catch {
        Write-Exception $_
        Log-Output "Upload to gw2raidar failed..."

        # The set of files is sorted in ascending order by its last write time. This
        # means, if we exit at the first failed file, that all files with an upload time prior
        # to this file must have succeeded. Thus, we'll save the "last upload time" as the
        # last update time of this file minus a little bit to ensure we attempt re-uploading it
        # on the next run. This avoids re-uploading lots of files if we fail in the middle of
        # a large sequence.
        (Get-Item $f).LastWriteTime.AddSeconds(-1) | Select-Object -Property DateTime | ConvertTo-Json | Out-File -Force $last_upload_file
        Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Write-Output "Upload to gw2raidar failed"
        Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Read-Host -Prompt "Press enter to exit."
        exit
    }

    # Then upload to dps.report (if configured) because the server will block until a permalink is available
    try {
        Maybe-UploadTo-DpsReport $config $f $dir $success
    } catch {
        Write-Exception $_
        Log-Output "Upload to dps.report failed..."

        # The set of files is sorted in ascending order by its last write time. This
        # means, if we exit at the first failed file, that all files with an upload time prior
        # to this file must have succeeded. Thus, we'll save the "last upload time" as the
        # last update time of this file minus a little bit to ensure we attempt re-uploading it
        # on the next run. This avoids re-uploading lots of files if we fail in the middle of
        # a large sequence.
        (Get-Item $f).LastWriteTime.AddSeconds(-1) | Select-Object -Property DateTime | ConvertTo-Json | Out-File -Force $last_upload_file
        Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Write-Output "Upload to dps.report failed"
        Write-Output "!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Read-Host -Prompt "Press enter to exit."
        exit
    }
}

# Save the current time as
$next_upload_time | Select-Object -Property DateTime| ConvertTo-Json | Out-File -Force $last_upload_file
# SIG # Begin signature block
# MIIFZAYJKoZIhvcNAQcCoIIFVTCCBVECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPUSThkIuK9OPt1ahFpuNiiGs
# FB+gggMCMIIC/jCCAeagAwIBAgIQFFuA0ERIe5ZFRAzvqUXg0TANBgkqhkiG9w0B
# AQsFADAXMRUwEwYDVQQDDAxKYWNvYiBLZWxsZXIwHhcNMTgxMDI4MDU1MzQzWhcN
# MTkxMDI4MDYxMzQzWjAXMRUwEwYDVQQDDAxKYWNvYiBLZWxsZXIwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDXGkNeGuDBzVQwrOwaZx8ovS5BfaSsG5xx
# 3qaOK7YDsvpcebJMVK6eyjVO8X49bu4Q23ESyAmyD6udo+nGow2HmBaadmx3XtTY
# BDJrlf0dvf3j6HKsY/L9PQ1qa2lASDRoGUTZygflijc+Q9JJo7EG/QefwLrKF1Bw
# vF7eg6remPiJmT9JwhmEDy2H8jZn32B8+AAaaoYxP62+1kayn/smhHYLHBlzPSN3
# c8M74jGwIVLWHcy+3GS5cLQ2TgRiqLjTQujKn7t5EasGjsUZLNl/1mMUae4kt35E
# l+IThauMio4vm2ooB169X1hKS9/cd83bxzGkmxHbNYBdLsQK6USlAgMBAAGjRjBE
# MA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQU
# tKQNud96B8lWJUbI02sltSDIExkwDQYJKoZIhvcNAQELBQADggEBAIC17zjVumO0
# kgo+Qn/bmePqejGCZl5ajfYhNLMEBCnK1wqZBtV/7sAgK8HNBDuVJWRShGCJle6T
# XQrt5MaVqE5RMOxRMkSBTHHw1n+y63kfSUgL/7/m1VMlpUHFqnC5nnkzQNpDABwz
# irro884sMu9rwzOn2GqoRfA9iFjdd3+6o1PTh0ms6rGP+U40cWXwLia/gHYS9Nfj
# SJtrPmWejpWCRGaEimyDZoK+KZNGGecphrbU20vgNUaKVz2ukESa4bdpaAbaG51Z
# 3wmtVSFveRwVuhDPTkRSp2h9sMGqfK3KJZW/CPRYYE/UwpXTNttMfftJ83btibZ3
# j/LuvKgyF94xggHMMIIByAIBATArMBcxFTATBgNVBAMMDEphY29iIEtlbGxlcgIQ
# FFuA0ERIe5ZFRAzvqUXg0TAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUB3d4HzMrBxOxIlX6G52x
# HL3xmqowDQYJKoZIhvcNAQEBBQAEggEAAcSN1udeaRFCYY9EZv++KJsAWWc0aSUq
# IT6FPmKprfRQRjhuBLYH6NHMRy1pGAo1u9JfSRUjQcxUyNkgK3TeLtmOlTGyOvSF
# E2aCRwv8poSwpdsd4lCUf+oYS+U7RatHenYnPOWa4i2PBgLDxFQgS3mwA2qEauPD
# olWud1vpmifV9wzF0t909CdejSBOzfgfDtH2kUUHepFMcwduRQCU6Fqcb5dh1vVN
# q+0qmhoox3wDXtFymMo5xO50bdgndW86+J3A3Gpns5vsQrcSOhW2KmJspPpDIajj
# Il7Xc84wgm7leCOJRcx2bT6SDtYVkvSbttas4jJQFHspxhRBOQ94XQ==
# SIG # End signature block
