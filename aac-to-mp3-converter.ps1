$folder_to_watch = 'C:\Users\rafae\Downloads\'
$file_name_filter = '*.aac'
# to archive .aac files
$destination = 'c:\temp\test\arc\'  
# below doesn't work due to hebrew in the string!
# $DestinationDirMP3 = 'C:\data\personal\עברית\cardbuilding\audio-files\hinative'
$DestinationDirMP3 = 'C:\data\personal\hinative-mp3'
$Watcher = New-Object IO.FileSystemWatcher $folder_to_watch, $file_name_filter -Property @{ 
    IncludeSubdirectories = $false
    NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
}
$VLCExe = 'C:\Program Files\VideoLAN\VLC\vlc.exe' 

$onCreated = Register-ObjectEvent $Watcher -EventName Created -SourceIdentifier FileCreated -Action {
   $path = $Event.SourceEventArgs.FullPath
   $name = $Event.SourceEventArgs.Name
   $changeType = $Event.SourceEventArgs.ChangeType
   $timeStamp = $Event.TimeGenerated
   Write-Host "The file '$name' was $changeType at $timeStamp"
   Write-Host $path

   # File Checks
    while (Test-LockedFile $path) {
      $i = 1
      Write-Host "in loop $i"
      Start-Sleep -Seconds .2
      $i++
    }
    # Move File
    Write-Host "moving $path to $destination"
    Move-Item $path -Destination $destination -Force -Verbose
    # build the path to the archived .aac file
    $SourceFileName = Split-Path $path -Leaf
    $DestinationAAC = Join-Path $destination $SourceFileName
    $MP3FileName = [System.IO.Path]::ChangeExtension($SourceFileName,".mp3")
    $DestinationMP3 = Join-Path $DestinationDirMP3 $MP3FileName
    $VLCArgs = "-I dummy -vvv $DestinationAAC --sout=#transcode{acodec=mp3,ab=48,channels=2,samplerate=32000}:standard{access=file,mux=ts,dst=$DestinationMP3} vlc://quit"
    Write-Host "args $VLCArgs"
    Start-Process -FilePath $VLCExe -ArgumentList $VLCArgs
    

}


function Test-LockedFile {
    param ([parameter(Mandatory=$true)][string]$Path)  
    Write-Host "Test-LockedFile a-entered $Path"
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
      Write-Host "file is locked..."
      return $true
    }
  }