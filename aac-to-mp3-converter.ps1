
# 2021-12-26
# Raf created this because on hinative.com, my main helper
# uses android or something and all her recordings are .aac files
# This is a problem because anki can't play these natively.
# So I have been clicky click converting them using vlc

# This script watches the downloads folder, and any .aac
# that shows up is auto converted to mp3.
# HUGE hassle saver!

# Below is per https://stackoverflow.com/a/49481797/147637
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding =
                    New-Object System.Text.UTF8Encoding

$folder_to_watch = 'C:\Users\rafae\Downloads\'
$file_name_filter = '*.aac'
# to archive .aac files
$destination = 'c:\temp\test\arc\'  
# below doesn't work due to hebrew in the string!
# $DestinationDirMP3 = "C:\data\personal\עברית\cardbuilding\audio-files\hinative"
$DestinationDirMP3 = 'C:\data\personal\hinative-mp3'
Write-Host $DestinationDirMP3
$Watcher = New-Object IO.FileSystemWatcher $folder_to_watch, $file_name_filter -Property @{ 
    IncludeSubdirectories = $false
    NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
}
$VLCExe = 'C:\Program Files\VideoLAN\VLC\vlc.exe' 

# before registering, unregister it, so there is no collision.
# the -EA flag tells it to run silently (as will throw an error if event is not already registered)
Unregister-Event -SourceIdentifier FileCreated -EA 0

$onCreated = Register-ObjectEvent $Watcher -EventName Created -SourceIdentifier FileCreated -Action {
   $path = $Event.SourceEventArgs.FullPath
   $name = $Event.SourceEventArgs.Name
   $changeType = $Event.SourceEventArgs.ChangeType
   $timeStamp = $Event.TimeGenerated
   Write-Host "The file '$name' was $changeType at $timeStamp"
   Write-Host $path

   # File Checks
    while (Test-LockedFile $path) {
      Start-Sleep -Seconds .2
    }
    # Move File
    Write-Host "moving $path to $destination"
    Move-Item $path -Destination $destination -Force -Verbose
    # build the path to the archived .aac file
    $SourceFileName = Split-Path $path -Leaf
    $DestinationAACwoQuotes = Join-Path $destination $SourceFileName
    $DestinationAAC = "`"$DestinationAACwoQuotes`""
    $MP3FileName = [System.IO.Path]::ChangeExtension($SourceFileName,".mp3")
    $DestinationMP3woQuotes = Join-Path $DestinationDirMP3 $MP3FileName
    $DestinationMP3 = "`"$DestinationMP3woQuotes`""
    $VLCArgs = "-I dummy -vvv $DestinationAAC --sout=#transcode{acodec=mp3,ab=48,channels=2,samplerate=32000}:standard{access=file,mux=ts,dst=$DestinationMP3} vlc://quit"
    Write-Host "args $VLCArgs"
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