
# 2021-12-26
# Raf created this because on hinative.com, my main helper
# uses android or something and all her recordings are .aac files
# This is a problem because anki can't play these natively.
# So I have been clicky click converting them using vlc

# This script watches the downloads folder, and any .aac
# that shows up is auto converted to mp3.
# HUGE hassle saver! This thing is real magic. Makes it SOOOO much easier to collab!

# Note: .ps1 files such as this with unicode strings MUST have
# BOM in the .ps1 file! VSCode does not do this by default for .ps1 !
# See references:
# -- https://stackoverflow.com/q/70499875/147637
# -- https://stackoverflow.com/a/54790355/147637

# NOTE! This code registers an event handler, that will stay in memory FOREVER
# (well, until the system reboots or until you UNREGISTER the handler!)
# To get the code to stop, you need to unregister the event handler.
# At a ps prompt:  Unregister-Event FileCreated

# ---------------------------------------------------------------------------------------------
# Find the default /downloads/ folder for the current user.
# source for this call: https://stackoverflow.com/a/57950443/147637
$folder_to_watch =  (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
$file_name_filter = '*.aac'         # We only look for .aac files
$destination = 'c:\temp\test\arc\'  # where to archive .aac files
# below with hebrew in the string only works if this .ps1 file has a BOM!!  No BOM, the script barfs!
$DestinationDirMP3 = "C:\data\personal\עברית\cardbuilding\audio-files\hinative"
Write-Host $DestinationDirMP3
$Watcher = New-Object IO.FileSystemWatcher $folder_to_watch, $file_name_filter -Property @{ 
    IncludeSubdirectories = $false
    NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
}
$VLCExe = 'C:\Program Files\VideoLAN\VLC\vlc.exe' 

# before registering, unregister it, so there is no collision when you keep 
# rerunning this thing during debugging and development.
# the -EA flag tells it to run silently (as will throw an error if event is not already registered)
Unregister-Event -SourceIdentifier FileCreated -EA 0

Register-ObjectEvent $Watcher -EventName Created -SourceIdentifier FileCreated -Action {
   $path = $Event.SourceEventArgs.FullPath
   $name = $Event.SourceEventArgs.Name
   $changeType = $Event.SourceEventArgs.ChangeType
   $timeStamp = $Event.TimeGenerated
   Write-Host "The file '$name' was $changeType at $timeStamp"
   Write-Host $path

    # OK, at this point the event has fired, and it is time to do stuff.
    
    # File Checks -- if file is locked, don't try to move it...
    while (Test-LockedFile $path) {
      Start-Sleep -Seconds .2
    }
    # Move File
    Move-Item $path -Destination $destination -Force -Verbose
    # build the path to the archived .aac file and the mp3 conversion target
    $SourceFileName = Split-Path $path -Leaf                            # grabs just the file name off the full path
    $DestinationAACwoQuotes = Join-Path $destination $SourceFileName    # bolt the file name to the destination path
    $DestinationAAC = "`"$DestinationAACwoQuotes`""                     # fully quote the destination, otherwise the Hebrew and space chars trash the vlc command
    $MP3FileName = [System.IO.Path]::ChangeExtension($SourceFileName,".mp3")
    $DestinationMP3woQuotes = Join-Path $DestinationDirMP3 $MP3FileName # do the same thing with the mp3 output file name...
    $DestinationMP3 = "`"$DestinationMP3woQuotes`""
    # This next must be double quoted so the powershell variable substitution will do its magic.
    $VLCArgs = "-I dummy -vvv $DestinationAAC --sout=#transcode{acodec=mp3,ab=48,channels=2,samplerate=32000}:standard{access=file,mux=ts,dst=$DestinationMP3} vlc://quit"
    Write-Host "args $VLCArgs"
    # This is the vlc command line to convert from .aac to .mp3
    Start-Process -FilePath $VLCExe -ArgumentList $VLCArgs
}

function Test-LockedFile {
    param ([parameter(Mandatory=$true)][string]$Path)  
    $oFile = New-Object System.IO.FileInfo $Path
    if ((Test-Path -Path $Path) -eq $false)
    {
      return $false
    }
  
    try
    {
      $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        if ($oStream)
        {
          $oStream.Close()
        }
        $false
    }
    catch
    {
      # file is locked by a process.
      return $true
    }
  }


  # To get the code to stop, you need to unregister the event handler.
  # At a ps prompt:  Unregister-Event FileCreated

  # Now one issue with this script is that it is kind of a TSR. It stays resident, but does not continue to run.
  # Here is a "normal powershell approach" to this, which has an empty loop running, so that you can press
  # ctrl-C and the event gets unregistered and the queue cleaned up.
  # https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/using-filesystemwatcher-correctly-part-2#
