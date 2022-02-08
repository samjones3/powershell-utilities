# This script is a small update to the one found here:
# https://mnaoumov.wordpress.com/2013/08/31/cpowershell-clipboard-watcher/

# This started in this SO thread: https://stackoverflow.com/q/71014273/147637
# This is expected to run fine on Win10 and Win11 (and probably other versions)

# This script binds the OS functions to monitor when new items are put on the clipbpard.
# It is a powershell script, that has been tested to work on Win10 and Win11.

[CmdletBinding()]
param
(
)
 
$script:ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }
Trap { throw $_ }
 
function Register-ClipboardWatcher
{
    if (-not (Test-Path Variable:Global:ClipboardWatcher))
    {
        Register-ClipboardWatcherType
        $Global:ClipboardWatcher = New-Object ClipboardWatcher
 
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action `
        {
            Unregister-ClipboardWatcher
        }
    }
 
    return $Global:ClipboardWatcher
}
 
function Unregister-ClipboardWatcher
{
    if (Test-Path Variable:Global:ClipboardWatcher)
    {
        $Global:ClipboardWatcher.Dispose();
        Remove-Variable ClipboardWatcher -Scope Global
        Unregister-Event -SourceIdentifier ClipboardWatcher
    }
}
 
function Register-ClipboardWatcherType
{
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -Language CSharp -TypeDefinition `
    @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
 
public class ClipboardWatcher : IDisposable
{
    readonly Thread _formThread;
    bool _disposed;
 
    public ClipboardWatcher()
    {
        _formThread = new Thread(() => { new ClipboardWatcherForm(this); })
                      {
                          IsBackground = true
                      };
 
        _formThread.SetApartmentState(ApartmentState.STA);
        _formThread.Start();
    }
 
    public void Dispose()
    {
        if (_disposed)
            return;
        Disposed();
        if (_formThread != null && _formThread.IsAlive)
            _formThread.Abort();
        _disposed = true;
        GC.SuppressFinalize(this);
    }
 
    ~ClipboardWatcher()
    {
        Dispose();
    }
 
    public event Action<string> ClipboardTextChanged = delegate { };
    public event Action Disposed = delegate { };
 
    public void OnClipboardTextChanged(string text)
    {
        ClipboardTextChanged(text);
    }
}
 
public class ClipboardWatcherForm : Form
{
    public ClipboardWatcherForm(ClipboardWatcher clipboardWatcher)
    {
        HideForm();
        RegisterWin32();
        ClipboardTextChanged += clipboardWatcher.OnClipboardTextChanged;
        clipboardWatcher.Disposed += () => InvokeIfRequired(Dispose);
        Disposed += (sender, args) => UnregisterWin32();
        Application.Run(this);
    }
 
    void InvokeIfRequired(Action action)
    {
        if (InvokeRequired)
            Invoke(action);
        else
            action();
    }
 
    public event Action<string> ClipboardTextChanged = delegate { };
 
    void HideForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        Load += (sender, args) => { Size = new Size(0, 0); };
    }
 
    void RegisterWin32()
    {
        User32.AddClipboardFormatListener(Handle);
    }
 
    void UnregisterWin32()
    {
        if (IsHandleCreated)
            User32.RemoveClipboardFormatListener(Handle);
    }
 
    protected override void WndProc(ref Message m)
    {
        switch ((WM) m.Msg)
        {
            case WM.WM_CLIPBOARDUPDATE:
                ClipboardChanged();
                break;
 
            default:
                base.WndProc(ref m);
                break;
        }
    }
 
    void ClipboardChanged()
    {
        if (Clipboard.ContainsText())
            ClipboardTextChanged(Clipboard.GetText());
    }
}
 
public enum WM
{
    WM_CLIPBOARDUPDATE = 0x031D
}
 
public class User32
{
    const string User32Dll = "User32.dll";
 
    [DllImport(User32Dll, CharSet = CharSet.Auto)]
    public static extern bool AddClipboardFormatListener(IntPtr hWndObserver);
 
    [DllImport(User32Dll, CharSet = CharSet.Auto)]
    public static extern bool RemoveClipboardFormatListener(IntPtr hWndObserver);
}
"@
 
}
 
function Register-ClipboardTextChangedEvent
{
    param
    (
        [ScriptBlock] $Action
    )
    # before registering, unregister it, so there is no collision when you keep 
    # rerunning this thing during debugging and development.
    # the -EA flag tells it to run silently (as will throw an error if event is not already registered)
    Unregister-Event -SourceIdentifier ClipboardWatcher -EA 0
    $watcher = Register-ClipboardWatcher
    Register-ObjectEvent $watcher -EventName ClipboardTextChanged -Action $Action -SourceIdentifier ClipboardWatcher
}
 
Register-ClipboardTextChangedEvent -Action `
    {
        param
        (
            [string] $text
        )
 
        Write-Host "Text arrived @ clipboard: $text"
    }