if ($DotFilesShowScriptEntry) { Write-Verbose -Message (Get-DotFilesMessage -Message $PSCommandPath) }

if (!(Test-IsWindows)) {
    return
}

if (!$env:ConEmuANSI -eq 'ON') {
    Write-Verbose -Message (Get-DotFilesMessage -Message 'Skipping ConEmu settings as not running under ConEmu.')
    return
}

Write-Verbose -Message (Get-DotFilesMessage -Message 'Loading ConEmu settings ...')

# Special prompt handling for PowerShell under ConEmu
# See: https://conemu.github.io/en/PowershellPrompt.html
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignment', '')]
$ConEmuPrompt = {
    # Let ConEmu know where the prompt ends
    $prompt = '{0}]9;12{1}' -f [char]27, [char]7

    # Let ConEmu know the current working dir
    if ($ExecutionContext.SessionState.Path.CurrentLocation.Provider.Name -eq 'FileSystem') {
        $prompt += '{0}]9;9;"{1}"{2}' -f [char]27, $ExecutionContext.SessionState.Path.CurrentLocation.Path, [char]7
    }

    return $prompt
}
