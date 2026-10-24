#Requires -Version 5.1

function Resolve-GitHubManifestInput {
    <#
    .SYNOPSIS
        把用户输入归一化为 GitHub 仓库软件源：源名（用户名/仓库）+ 清单地址。
    .DESCRIPTION
        软件源只支持 GitHub 仓库，接受三种写法（均支持粘贴，自动清理引号与不可见字符）：
          ① 用户名/仓库（如 owner/repo）
             → 仓库根目录、默认分支：https://raw.githubusercontent.com/<用户名>/<仓库>/HEAD/manifest.json
          ② 仓库页地址（如 https://github.com/owner/repo）
             → 同上；若带 /tree/<分支>[/<目录>] 或 /blob/<分支>/<文件> 则保留分支与路径
          ③ 清单地址（如 https://raw.githubusercontent.com/owner/repo/main/manifest.json）
             → 原样保留其分支与路径
        其它站点或无法识别的写法一律报错（不静默猜测地址）。
    .OUTPUTS
        @{ Ok; Name; Repo; Url; Error }
    #>
    param([string]$RepoOrUrl)

    $result = @{ Ok = $false; Name = ''; Repo = ''; Url = ''; Error = '' }
    $text = ConvertTo-WinstTrimmedInput -Value $RepoOrUrl
    if (-not $text) {
        $result.Error = '请输入 GitHub 仓库（如 owner/repo）或清单地址'
        return $result
    }

    $repo = ''
    $manifestUrl = ''

    if ($text -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        # 简写：用户名/仓库（允许尾部 .git 与斜杠）
        if ($text -match '^([^/\s]+)/([^/\s]+?)(?:\.git)?/?$') {
            $repo = '{0}/{1}' -f $Matches[1], $Matches[2]
            $manifestUrl = 'https://raw.githubusercontent.com/{0}/HEAD/manifest.json' -f $repo
        } else {
            $result.Error = '输入格式无法识别：请填写「用户名/仓库」，或 GitHub 仓库 / 清单的完整地址'
            return $result
        }
    } else {
        $uri = $null
        if (-not [Uri]::TryCreate($text, [UriKind]::Absolute, [ref]$uri)) {
            $result.Error = '地址格式不正确，请检查后重试'
            return $result
        }
        $hostName = $uri.Host.ToLowerInvariant()
        $segments = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { $_ -ne '' })

        if ($hostName -eq 'github.com' -or $hostName -eq 'www.github.com') {
            if ($segments.Count -lt 2) {
                $result.Error = '地址里没有仓库信息：应形如 https://github.com/用户名/仓库'
                return $result
            }
            $repo = '{0}/{1}' -f $segments[0], ($segments[1] -replace '\.git$', '')
            $ref = 'HEAD'
            $path = 'manifest.json'
            if ($segments.Count -ge 3) {
                $kind = $segments[2].ToLowerInvariant()
                if ($kind -ne 'tree' -and $kind -ne 'blob') {
                    $result.Error = '不支持的仓库地址写法：只支持仓库主页、/tree/<分支>、/blob/<分支>/<文件>'
                    return $result
                }
                if ($segments.Count -ge 4) { $ref = $segments[3] }
                if ($segments.Count -ge 5) {
                    $path = ($segments[4..($segments.Count - 1)] -join '/')
                    if ($kind -eq 'tree' -and $path -notmatch '\.json$') {
                        $path = $path.TrimEnd('/') + '/manifest.json'
                    }
                }
            }
            $manifestUrl = 'https://raw.githubusercontent.com/{0}/{1}/{2}' -f $repo, $ref, $path
        } elseif ($hostName -eq 'raw.githubusercontent.com') {
            if ($segments.Count -lt 4) {
                $result.Error = '清单地址缺少仓库或分支信息：应形如 https://raw.githubusercontent.com/用户名/仓库/分支/manifest.json'
                return $result
            }
            $repo = '{0}/{1}' -f $segments[0], $segments[1]
            $manifestUrl = $text
        } else {
            $result.Error = '软件源只支持 GitHub 仓库（github.com / raw.githubusercontent.com），请勿使用其它站点'
            return $result
        }
    }

    $parts = @($repo -split '/')
    if ($parts.Count -ne 2) {
        $result.Error = '仓库名称无法识别，请形如「用户名/仓库」'
        return $result
    }
    if ($parts[0] -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*)$') {
        $result.Error = ('"{0}" 不是有效的 GitHub 用户名（只能由字母、数字、短横线组成）' -f $parts[0])
        return $result
    }
    if ($parts[1] -notmatch '^[A-Za-z0-9._-]+$') {
        $result.Error = ('"{0}" 不是有效的仓库名（只能由字母、数字、点、下划线、短横线组成）' -f $parts[1])
        return $result
    }

    $result.Ok = $true
    $result.Repo = $repo
    $result.Name = $repo
    $result.Url = $manifestUrl
    return $result
}
