#Requires -Version 5.1

function Get-WinstKeptItem {
    <#
    .SYNOPSIS
        逐层定位保留项；一层全是固定名称时直接取路径，命中目录即交给复制命令。
    #>
    param([string]$Root, $Rules)

    $pending = New-Object 'System.Collections.Generic.Stack[object]'
    $pending.Push(@{ Path = $Root; Rules = $Rules })
    while ($pending.Count) {
        $folder = $pending.Pop()
        if ($folder.Rules | Where-Object { -not $_.Literal } | Select-Object -First 1) {
            $items = Get-ChildItem -LiteralPath ('FileSystem::' + $folder.Path) -Force -ErrorAction Stop
        } else {
            $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $items = foreach ($rule in $folder.Rules) {
                $name = $rule.Literal
                if (-not $names.Add($name)) { continue }
                try { Get-Item -LiteralPath ('FileSystem::' + (Join-WinstPath $folder.Path $name)) -Force -ErrorAction Stop }
                catch [System.Management.Automation.ItemNotFoundException] { }
            }
        }

        foreach ($item in $items) {
            $childRules = @()
            $matched = $false
            foreach ($rule in $folder.Rules) {
                if ($rule.Recursive) {
                    if ($rule.Regex.IsMatch($item.FullName.Substring($Root.Length + 1))) { $matched = $true; break }
                    $childRules += $rule
                    continue
                }
                if ($rule.Literal) {
                    if (-not $item.Name.Equals($rule.Literal, [StringComparison]::OrdinalIgnoreCase)) { continue }
                } elseif (-not $rule.Regex.IsMatch($item.Name)) { continue }

                if (-not $rule.Next) { $matched = $true; break }
                $childRules += $rule.Next
            }
            $isLink = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ($matched) {
                if ($isLink) { throw ('保留项是重解析点：' + $item.FullName) }
                $item
            } elseif ($childRules.Count -and $item.PSIsContainer -and -not $isLink) {
                $pending.Push(@{ Path = $item.FullName; Rules = $childRules })
            }
        }
    }
}
