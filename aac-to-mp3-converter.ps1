
# 2021-12-26
# Raf created this because on hinative.com, my main helper
# uses android or something and all her recordings are .aac files
# This is a problem because anki can't play these natively.
# So I have been clicky click converting them using vlc
# (And a newer collaborator submits a lot of .wav files, which are LARGE)

# This script watches the downloads folder, and any .aac, .wav and .mp4
# that shows up is auto converted to mp3.
# HUGE hassle saver! This thing is real magic. Makes it SOOOO much easier to collab!

# Note: .ps1 files such as this with unicode strings MUST have
# BOM in the .ps1 file! VSCode does not do this by default for .ps1 !
# See references:
# -- https://stackoverflow.com/q/70499875/147637
# -- https://stackoverflow.com/a/54790355/147637

# Usage:
# Raf creates an icon to this ps1 in his startup folder:
# %appdata%\Microsoft\Windows\Start Menu\Programs\Startup
# The target for the shortcut is:
#     C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\develop\utils\powershell\aac-to-mp3-converter.ps1
#
# Set it to run minimized
# And voila.... watch the output folder and watch the magic!


# ---------------------------------------------------------------------------------------------
# Find the default /downloads/ folder for the current user.
# source for this call: https://stackoverflow.com/a/57950443/147637
$folder_to_watch =  (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
$file_name_filter = '*.*'           # We look all new files, since we cannot filter on multiple extensions
                                    # Basically, we can either register multiple events (one per extension)
                                    # or we look for all file create events, and filter in our code. This script
                                    # does the latter.
$extensionarray = '.aac', '.wav', '.mp4'    # array of extensions we are interested in. Just add to this list to convert to mp3
$eventname = 'FileCreatedEvent2'
$destination = 'c:\temp\test\arc\'  # where to archive downloaded files
# literal Hebrew strings ALSO must be in double-quotes... single quotes don't work around unicode in powershell.
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
Unregister-Event -SourceIdentifier $eventname -EA 0

# We look for Changed events, which shows us file creations and renames.... and
# when firefox downloads a file as .part, it seems to rename it to .wav, and looking for
# Created event misses that event...
# alternate approach, not used, register to both Created and Renamed: https://stackoverflow.com/a/71445023/147637
Register-ObjectEvent $Watcher -EventName Changed -SourceIdentifier $eventname -Action {
   $path = $Event.SourceEventArgs.FullPath
   $name = $Event.SourceEventArgs.Name
   $fileextension = [System.IO.Path]::GetExtension($name) # extract extension as string from filename
   $changeType = $Event.SourceEventArgs.ChangeType
   $timeStamp = $Event.TimeGenerated
   $pattern = '[^a-zA-Z3]'
   $codecName = $fileextension -replace $pattern, ''   # strip the period out of the extension
   $sizeinbytes = (Get-Item $path).length

   Write-Host "The file '$name' with extension '$fileextension' was $changeType at $timeStamp of size $sizeinbytes"

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
                return $false
            }
            $false
        }
        catch
            {
                # file is locked by a process.
                return $true
            }
    }
   
:processingLoop  foreach ( $extensiontoprocess in $extensionarray )
    {
         if ($fileextension -eq $extensiontoprocess)
        {
            # OK, at this point the event has fired, and it is time to do stuff.
            Write-Host "'$path' and the codecname is '$codecName' and the extensionarray has '$extensionarray' elements"
   
           Write-Host " FILE $path is size "(Get-Item $path).length
           $i = 1 
           while (((Get-Item $path).length -eq 0kb) -and  ([System.IO.File]::Exists($path))) 
                {
                # This loop is actually constructive, because it forces the process to wait until the 
                # the file has been written out....
                Write-Host "file size of $path is " (Get-Item $path).length
                Start-Sleep -Seconds .1 
                $i++
                    # If the file stays at 0 bytes, get out of the loop and forget this file...
                    # means there is a download
                if ($i=11) {continue processingLoop}
             }
                     
            # File Checks -- if file is locked, don't try to move it...
            while (Test-LockedFile $path) {
                Start-Sleep -Seconds .1
            }
            # Move File
            Move-Item $path -Destination $destination -Force -Verbose
            # build the path to the archived .aac file and the mp3 conversion target
            $SourceFileName = Split-Path $path -Leaf                            # grabs just the file name off the full path
            $DestinationAACwoQuotes = Join-Path $destination $SourceFileName    # bolt the file name to the destination path
            $DestinationAAC = "`"$DestinationAACwoQuotes`""                     # fully quote the destination, otherwise the Hebrew and space chars trash the vlc command
            $SourceFileName = $SourceFileName  -replace '[,"]'                  # strip out problem chars in file name
            $MP3FileName = [System.IO.Path]::ChangeExtension($SourceFileName,".mp3")
            $DestinationMP3woQuotes = Join-Path $DestinationDirMP3 $MP3FileName # do the same thing with the mp3 output file name...
            $DestinationMP3 = "`"$DestinationMP3woQuotes`""
            # This next must be double quoted so the powershell variable substitution will do its magic.
            $VLCArgs = "-I dummy -vvv $DestinationAAC --sout=#transcode{acodec=mp3,ab=48,channels=2,samplerate=32000}:standard{access=file,mux=ts,dst=$DestinationMP3} vlc://quit"
            Write-Host "args $VLCArgs"

            # The following section shows that the file test functions fail if the file name is double quoted...
            Write-Host "DestinationAAC: $DestinationAAC  "(Get-Item $DestinationAAC).length "and "([System.IO.File]::Exists($DestinationAAC)) " and "
            Write-Host "DestinationAACwoQuotes: $DestinationAACwoQuotes  "(Get-Item $DestinationAACwoQuotes).length "and "([System.IO.File]::Exists($DestinationAACwoQuotes)) " and "
            
            # We have to do this test, because it seems that vlc will create a 0 byte
            # destination mp3 file even when the source file does not exist!
            if (((Get-Item $DestinationAACwoQuotes).length -gt 0kb) -and  ([System.IO.File]::Exists($DestinationAACwoQuotes)))
                {
                    # This is the vlc command line to convert from aac/wav/mp4 to .mp3
                    Start-Process -FilePath $VLCExe -ArgumentList $VLCArgs
                } else {
                    Write-Host "NOT CONVERTED: File to convert $DestinationAACwoQuotes is missing or 0 bytes"
                }
        }
    }  
}
    # To get the code to stop, just hit ctrl-C in the script box. 
  
    # Here is a "normal powershell approach" to this, which has an empty loop running, so that you can press
    # ctrl-C and the event gets unregistered and the queue cleaned up.
    # https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/using-filesystemwatcher-correctly-part-2#
      

  # The below is per https://stackoverflow.com/a/71368404/147637
  # Raf, the noob at event driven coding, didn't see the need for it until now.
  # But now you can debug! 
  try {
    # At the end of the script... 
    while ($true) {
        Start-Sleep -Seconds .2
    }    
    }
catch {}
Finally {
    # Work with CTRL + C exit too !
    # Clean up the registered event...
    Unregister-Event -SourceIdentifier $eventname 
    }
