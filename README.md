# L0G-101086 Automated log uploads

A collection of scripts intended for posting links to uploaded EVTC encounter
report files generated by [ArcDPS](https://www.deltaconnected.com/arcdps). It
supports uploading to both to both the [dps.report](https://dps.report/) and
[GW2 Raidar](https://www.gw2raidar.com/) websites, and automatically
generating a discord comment linking back to the uploaded files.

It is authored by Jacob Keller a.k.a.
[platinummyr](https://www.reddit.com/u/platinummyr) and is available under a
simple 3-clause BSD license.

Please file issues at
[GitHub](https://github.com/jacob-keller/L0G-101086/issues) if you have any
trouble setting the script up, or have requests for improvement. [Pull
Requests](https://github.com/jacob-keller/L0G-101086/pulls) are also welcome!


## Requirements

* Guild Wars 2
* ArcDPS
* PowerShell 5
* RestSharp

The scripts are intended for uploading EVTC reports generated for Guild Wars
2, using the ArcDPS addon.

The scripts are written in Power Shell and are known to work with the most
recent version 5 release. They do not currently work with Powershell 6.
Generally Power Shell 5 is installed in Windows by default. More information
can be found at [Microsoft's
documentation](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell?view=powershell-5)

Pull requests to add Powershell 6 support are welcome, but it is not something
I plan on doing soon.

Due to the complexity of including files when using the PowerShell
Invoke-RestMethod cmdlt, the scripts rely on the RestSharp .NET library for
handling some of the REST APIs. The GitHub release of this project include a
copy of the RestSharp.dll, as it is available under the Apache 2.0 License.


## Installation and Setup

The scripts require some manual setup in order to work. First, download the
scripts and place them somewhere convenient on your system. You will also need
the RestSharp.dll and simpleArcParse.exe binaries. You can download these from
the [GitHub release page](https://github.com/jacob-keller/L0G-101086/releases)
or compile them yourself manually. simpleArcParse code is available in the
[repository](https://github.com/jacob-keller/L0G-101086/tree/master/simpleArcParse).
RestSharp is available on its [GitHub
page](https://github.com/restsharp/RestSharp)

The scripts rely on a configuration file written in in JSON for setup. See the
[configuration](#the-configuration-file) section for more details about the
various options and controls available.

Once you've updated the sample configuration and renamed it, you should be
able to run the [upload-logs](#upload-logs.ps1) script to upload logs to
dps.report and/or gw2raidar. Then you can run the
[format-encounters](#format-encounters.ps1) script to create and publish a
comment with links to the different encounters run since the last time you ran
the format script.

The [update-arcpds](#update-arcdps.ps1) script is useful for automatically
updating ArcDPS and related utilities. The [launcher](#launcher.ps1) script is
useful for those that use [Gw2 Launch
Buddy](https://github.com/TheCheatsrichter/Gw2_Launchbuddy). It will run the
update-arcdps.ps1 script first, and then start Launch Buddy.


## Issues

There are a few known issues that you may encounter. If you run into issues
not documented here, please file an issue or conact the author for assistance.

##### RestSharp.dll is not loading?

You may see an issue with loading the RestSharp.dll file, similar to the
following exception:

```
Add-Type : Could not load file or assembly 'file:///C:\Users\Corey\Documents\Guild Wars 2\addons\arcdps\RestSharp.dll' or one of its dependencies. Operation is not supported. (Exception from HRESULT: 0x80131515)
At C:\Users\Corey\Documents\Guild Wars 2\addons\arcdps\upload-logs.ps1:98 char:1
+ Add-Type -Path $config.restsharp_path
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Add-Type], FileLoadException
    + FullyQualifiedErrorId : System.IO.FileLoadException,Microsoft.PowerShell.Commands.AddTypeCommand
```

This is likely caused because Windows needs to be told to unblock the file,
which can be done from the powershell console like so:

```
Unblock-File -Path RestSharp.dll
```

This will not take affect until you reload the PowerShell console.

##### simpleArcParse.exe not running, disappearing on call to upload-logs.ps1

Some antivirus software may prevent the execution of simpleArcParse.exe, and
possibly quarentine or even delete the exeucutable. You might see an exception
when upload-logs.ps1 is run.

If this is happening, you should check antivirus software and ensure that the
simpleArcParse executable is not blocked.

##### Powershell Execution Policy

These scripts have been self-signed with a private key, which was not
generated by a public key authority. Thus, even though the scripts are signed,
your computer may not automatically trust them.

The simplest fix is to unblock the files using the [Unblock-File](
https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file?view=powershell-6)
cmdlet. This will allow the script to be run assuming your default execution
policy is RemoteSigned. For more information about the execution policies, see
the [Microsoft's Execution
Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
page.

## The Configuration File

Configuration for the scripts is located in l0g-101086-config.json, which is a
JSON file containing various parameters that control how the scripts operate.
A sample configuration is located at l0g-101086-config.sample.json, which is a
good starting point.

### config_version

This field represents the configuration version format. It should not be
changed unless you know what you are doing. Currently the valid values are "1"
and "2". The [configure-v2-builds.ps1](#configure-v2-guilds.ps1) script is
provided to migrate from the deprecated v1 configuration to the newer v2
configuration. The current sample configuration is already version 2, so this
script is only useful for those who ran the older versions of the script which
used the previous v1 configuration format.

### debug_mode

This field enables debug oprations, and is generally only useful if you are
developing additions to the scripts. The sample configuration sets this to
false, and for normal use it should not be set to true. Currently this just
enables displaying extra data to the console as the scripts run.

### experimental_arcdps

If set to true, this enables the [update-arcdps.ps1](#update-arcdps.ps1)
script to grab experimental versions of ArcDPS. If there is no experimental
version of ArcDPS available, it will fall back to the regular version. Set
this to true if you wish to use experimental versions of ArcDPS, or false if
you only wish to use the normal stable releases. Only affects
update-arcdps.ps1.

### arcdps_logs

This variable should be set to the path of the arcdps.cbtlogs directory which
contains your generated EVTC files. The scripts understand to interpret the
%UserProfile% string as the User Profile environment variable. This must be
set for the upload-logs.ps1 and format-encounters.ps1 scripts to work
correctly

### discord_json_data

This variable specifies a path to store the JSON data that is sent to discord
webhooks, and is used to save potential data incase there are issues with the
discord posts

### extra_upload_data

This variable specifies a path to store data about EVTC files as parsed by
simpleArcParse, and must be set for [upload-logs.ps1](#upload-logs.ps1) and
[format-encounters](#format-encounters.ps1) to work properly.

### last_format_file

Specifies a path to a file which contains the timestamp of the last time that the
[format-encounters.ps1](#format-encounters.ps1) script was run. The
format-encounters.ps1 script will only publish encounters which are newer than
this time stamp, and will update the timestamp after running.

### last_upload_file

Specifies the path to a file which contains the timestamp of the last time
that the [upload-logs.ps1](#upload-logs.ps1) script was run. The
upload-logs.ps1 script will only upload logs newer than this timestamp, and
will update the timestamp after running. This is used to avoid uploading old
encounters.

### simple_arc_parse_path

This variable configures the path to the simpleArcParse.exe. This must be set
in order to enable the [upload-logs.ps1](#upload-logs.ps1) script to work
properly.

### upload_log_file

Specifies the path to the log file for the [upload-logs.ps1](#upload-logs.ps1)
script. Useful output will be stored in this file, and it may be useful for
debugging, or checking if files have been uploaded properly.

### format_encounters_log

Specifies the path to the log file for the
[format-encounters.ps1](#format-encounters.ps1) script. Useful output will be
stored in this file, and it may be useful for debugging why some encounters
are not posted properly.

### guildwars2_path

Specifies the path to where Guild Wars 2 is installed. Used by the
[update-arcdps.ps1](#update-arcdps.ps1) script to figure out where to install
the ArcDPS dlls

### launchbuddy_path

Specifies the path to where the GW2 Launch Buddy executable is installed. Only
used by the [launcher.ps1](#launcher.ps1) script to execute Gw2 Launch Buddy
after updating ArcDPS.

### dll_backup_path

Specifies the path to where .dll backups should be made. Used by the
[update-arcdps.ps1](#update-arcdps.ps1) script to backup .dll files before
over-writing them when downloading updates.

### restsharp_path

Must be set to the path where RestSharp.dll is located. Used by the
[upload-logs.ps1](#upload-logs.ps1) and
[format-encounters.ps1](#format-encounters.ps1) scripts to enable uploading
log files using the REST APIs for the associated websites.

### gw2raidar_token

The gw2raidar API token to use when uploading to GW2 Raidar. Must be set if
Gw2 Raidar uploads are enabled. For convenience the
[configure-gw2raidar-token.ps1](#configure-gw2raidar-token.ps1) script is
provided to set this based on your gw2raidar account.

### dps_report_token

The dps.report API token to use when uploading to dps.report. This should be
set to a random string that you keep safe like a password, as it is used by
dps.report to allow looking up which encounters you uploaded.

### dps_report_generator

Sets the dps.report generator to use. Can be "ei" for EliteInsights, or "rh"
for the old RaidHeros. It is recommended to use "ei".

### upload_dps_report

Set to true to "no" to disable uploading to dps.report. Set to "successful"
to enable uploading only the successful encounters to dps.report. Set to "all"
to upload all encounters to dps.report. The default is to upload only
successful encounters. Note that "none" is an alternative spelling of "no", and
"yes" is an alternative spelling of "all".

### upload_gw2raidar

Set to "no" to disable uploading to gw2raidar. Set to "successful" to only
upload successful encounters to gw2raidar. Set to "all" to upload all
encounters to gw2raidar. The default is to upload all encounters to gw2raidar,
as the website uses this information to generate useful statistics across all
logs uploaded. Note that "none" is an alternative spelling of "no", and "yes"
is an alternative spelling of "all"

### guilds

The guild subsection is used to configure which "guild" an encounter was run
by. This is primarily used as a method to allow posting different enounters to
different guild discords. Note that guilds is an array object, so the
configuration file supports multiple different guilds, with their own options.
See the l0g-101086-config.multipleguilds.json for an example configuration file
that has multiple guilds configured.

##### name

The name of the guild, used as a shorthand when posting to discord

##### priority

A number indicating priority when deciding which guild may be considered as
the main guild for an encounter. Lower numbers win ties based on other data.

##### gw2raidar_category

If uploading to gw2raidar, sets the category for the upload.

* 0: "Guild / Static"
* 1: "Training"
* 2: "PUG"
* 3: "Low Man /Sells"

##### gw2raidar_tag

The tags to use when uploading to gw2raidar. Can be a comma separated list.

#### discord_map

A map of guild members associated with this guild, and if available, their
discord ping identifier. The players are also used as the determiner for which
players are part of the guild. See [Configuring Discord
Accounts](#configuring-gw2-&-discord-accounts) for more information about how
to obtain the discord account ids.

##### threshold

The minimum number of players required to recognize the encounter as part of
this guild. Useful to exclude treating the guild as the main guild unless a
minmum number of players from the guild have joined. Uses the
[discord_map](#discord_map) as the source of data for players in the guild.
Note that if an encounter does not have enough players to reach the minimum
threshold for any guild in the configuration file, then it will not be posted.
For this reason, it is recommended to have at least one guild with a threshold
of zero to avoid this.

##### webhook_url

The URL for the discord webhook to use when posting to this guild.

##### thumbnail

The URL for a thumbnail icon to include in the discord embed post. If unset or
set to the empty string, then no image will be included.

##### emoji_map

A mapping between boss encounters and discord emoji ids to use when posting
for this guild. The IDs are server specific, so they must be emojis uploaded
to that server. See [Configuring Emojis](#configuring-emojis) for more
details.

##### raids

A boolean indicating if this guild should have raid encounters posted to it. If
set to false, then the guild will not be assigned as the owner of a raid
encounter. If set to true, then the raid encounter may be posted
to this discord webook URL. If not set, the default is true.

##### fractals

A boolean indicating if this guild should have fractal encounters posted to
it. If set to false, then this guild will not be assigned as the owner of a
fractal encounter. If set to true, then fractal encounters may be posted to
this discord webhook URL.

##### everything

If set to true, all posts will also be copied to this guild's discord webhook
URL. Useful to have a single server which receives all posts, while other
guild discords only receive posts for their own guild.

##### show_duration

An optional configuration setting that can be used to disable showing the
encounter duration when publishing. Set to false to disable including the
duration when formatting the encounters. If the value is not set, it will
default to true.

##### simpleArcParse

The simpleArcParse utility is written in C++ so depends on a C++ compiler.
Visual Studio should work, but I used
[CodeBlocks](https://www.codeblocks.org) with the [MinGW](http://www.mingw.org/)
compiler suite. I have a CodeBlocks project file included in the repository
which should work out of the box.

If you do not wish to bother compiling simpleArcParse, the [Github
Release](https://github.com/jacob-keller/L0G-101086/releases) page can be used
to download a precompiled binary of the program. You can download this and
update the configuration to point to it instead of compiling yourself.

## Scripts

There are several scripts, and it may be confusing which ones to run. The
primary two scripts for uploading logs are the
[upload-logs.ps1](#upload-logs.ps1) script, and the
[format-encounters.ps1](#format-encounters.ps1) script. Other scripts may be
useful to run once during initial setup, or for updating ArcDPS.

For the main scripts, shortcut files are provided which make running the
script as easy as double clicking.

The following sections provide extra information about each script and its
main purpose.

### update-arcdps.ps1

This script is used to automate the process of updating ArcDPS and its
associated extensions. It will download the latest version of the following
DLLs

* d3d9.dll - The ArcDPS dll
* d3d9_arcdps_buildtemplates.dll - The build templates extension
* d3d9_arcdps_extras.dll - The ArcDPS extras dll
* d3d9_arcdps_mechanics.dll - The ArcDPS mechanics extension

It downloads the DLLs into both the top level and \bin64 directories, as some
Gw2 launch options change the path where the DLLs must be located. This makes
the DLLs compatible with both normal launching and with launching via Gw2
Launch Buddy.

### upload-logs.ps1

This script will upload EVTC log files to dps.report and/or gw2raidar. It
stores the last time that it ran in a JSON file, and will only upload new
encounters since the last time it was run. You can configure whether to upload
to dps.report or gw2raidar using the configuration file.

Additionally, extra data about each encounter is stored in the
[extra_upload_data](#extra_upload_data) directory. This includes the player
list, success/failure, and boss ID. This data is used by the
[format-encounters.ps1](#format-encounters.ps1) script in order to generate
the report.

You must have configured at least one guild for the upload to work properly,
as it will not upload encounters which are not associated with at least one
guild in the configuration file.

The script will recursively scan the contents of the arcdps.cbtlogs folder, so
it is not confused by the options to store encounters by guild or character
name. It additionally can find either compressed or uncompressed logs.

### format-encounters.ps1

The format-encounters.ps1 script will actually publish the encounters to the
associated discord webhook URL. It will scan all the new EVTC data generated
in the [extra_upload_data](#extra_upload_data) directory, and create comments
to post to the associated discord channel. Encounter lists will be separated
by guild, and by day. The encounters will be sorted by time they were run. A
header will be added which shows the guild name, date, and which wings were
run. A footer is added which shows the players who ran in at least one
encounter for that day.

Due to the nature of the gw2raidar website, it is possible that not all
gw2raidar links will be ready if the script is run in rapid succession with
the [upload-logs.ps1](#upload-logs.ps1) script. For this reason, if gw2raidar
uploads are enabled it is recommended to wait a few minutes after running the
upload script.

### configure-discord-account-map.ps1

This script may be useful to help configure the discord account mapping for a
guild, rather than manually editing the configuration. It will run in the
command prompt, and ask which guild to edit. It supports adding or removing
players.

For more information about how to configure discord account ids, see
[configuring discord accounts](#configuring-gw2-&-discord-accounts).

### configure-emoji-map.ps1

This script is provided to configure the emoji mapping for a guild. It will
ask for the emoji id of each boss. For more information about how to obtain
these IDs, see [configuring-emojis](#configuring-emojis)

### configure-gw2raidar-token.ps1

This script is used to configure the gw2raidar token used for uploading. Since
this value must match the token associated with your gw2raidar account, this
script will prompt you for your gw2raidar credentials, and then use the API to
obtain the token and update the configuration.

If you do not trust the script with your username and password, this may be
done manually via the [gw2raidar API
page](https://www.gw2raidar.com/api/v2/swagger) directly.

### configure-v2-guilds.ps1

This script is provided for users who previously had a v1 configuration which
did not support multiple guilds. The old configuration format had all the
guild-specific configurations stored at the top level of the configuration.
This script will automatically convert the v1 configuration into the v2
configuration with a single guild. It should not be necessary to run this on a
new installation.

### launcher.ps1

This script is provided as a mechanism to run the
[update-arcdps.ps1](#update-arcdps.ps1) script, and then start Gw2 Launch
Buddy.

### l0g-101086.psm1

This is a shared module file containing functions used by the scripts, and
shoudl be kept at the root of the script installation.

### simpleArcParse.Tests.ps1

This script contains tests for the simpleArcParse utility and is used during
development to ensure proper functionality. It does not serve a purpose for
general users.

## simpleArcParse

The simpleArcParse utility is used by the [upload-logs.ps1](#upload-logs.ps1)
script in order to extract useful information out of the EVTC encounter files.
Primarily it is used to grab the player list, the boss name and id, and the
success/failure status of the encounter.

It is not really a complete boss parser, and is instead intended to run very
fast and extract the minimum information useful for uploading logs. It is
written in C++

## Other information

##### uploading to dps.report

The dps.report site does not use a formal account system. Currently the
dps.report token is basically just a magic string which associates all the
uploads to that string. You should set the
[dps_report_token](#dps_report_token) to a random string, and keep it safe
much like you would a password.

##### configurating guilds

While there is a [configure-v2-guilds.ps1](#configure-v2-guilds.ps1) script,
it is not intended to be used for general guild configuration.

The [configure-emoji-map.ps1](#configure-emoji-map.ps1) and
[configure-discord-account-map.ps1](#configure-discord-account-map.ps1)
scripts may be useful for setting up some of the configuration.

You must configure at least one guild in order for upload-logs.ps1 and
format-encounters.ps1 to work. If you were previously using a v1
configuration, there is a provided script to migrate to the v2 guilds format.

Guilds are used to tie encounters to specific discord webhooks. The list of
guild members stored in the discord map is used for this purpose. An encounter
will be considered as belonging to the guild which has the most members
partaking in the encounter. In the case of ties, the priority number of the
guild will be used to break the tie (lower numbers mean higher priority, with
1 being the highest priority guild).

You may configure a guild with a threshold. This is the minimum number of
guild members who must participate in order for the encounter to be
considered as that guild.

You may also configure whether a guild runs fractal encounters. If disabled,
fractal encounters will not consider that guild when determining which guild
ran an encounter.

It may be possible that an encounter does not belong to any configured guild.
In this case, the encounter will simply be ignored. If you wish all encounters
to be considered, add a guild with no players, a threshold of zero, and a low
priority as a fallback.

If you wish to add a player as a guild member, even if they do not have a
discord id, simply add them to the discord map, and set the contents to be the
same as their gw2 username (or any other contents you wish to display in the
player list, such as a nickname).

##### configuring emojis

In order to show icons before boss names you must have server emojis enabled.
Unfortunately there is no way for a webhook to include an image in the title
sections, so emojis are required. You may opt out of using emojis by leaving
the emoji map for a guild empty.

If you wish to configure emojis, you must determine the discord ID of the
emoji you want to use for each boss.

To generate this text, type the emoji into one of the channels of your discord
server, prefixed with a backslash. For example if your emoji is :kc: then type

```
\:kc:
```

This should show some text similar to

```
<:kc:311578870686023682>
```

For each boss you want an icon, you must generate the id text and place it
within the emoji map. It is possible you may need to unicode escape the '<'
and '>' characters.

##### configuring gw2 & discord accounts

The upload-logs.ps1 and format-encounters.ps1 scripts rely on the discord map
to provide a list of players who are considered members of the guild.
upload-logs.ps1 uses the account names to determine which encounters belong to
which guilds.

To configure a successful discord map, you need to obtain the discord id for
the account name on discord. This is done by obtaining the id for the
@mention.

To generate this mention, you can enter their discord name into a message
prefixed with a backslash.

For example, to generate the id for the account serenamyr#8942, you could type

```
\@serenamyr#8942
```

into a discord channel. It should return text similar to

```
<@119167866103791621>
```

This text is the id of the particular mention. You should include this in the
discord map hash table as the value for the matching gw2 account name.

## Questions?

If you have questions, issues, or simply wish help in setting the scripts up,
you may contact me in multiple ways. The easiest is to create a GitHub issue
with details about the issue or bug.

You may also contact me on reddit at /u/platinummyr, or on discord at
@serenamyr#8942. Finally, you can mail or PM me in Guild Wars 2 at "Serena
Sedai.3064"
