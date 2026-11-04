#Requires -Version 5.1

function Get-WinstBrowserPageHash {
    <#
    .SYNOPSIS
        在无头浏览器会话里按软件源声明的 hashClick 点控件，再从可见文案里读出唯一摘要。
    .DESCRIPTION
        给 files[0].hashFrom: "page" 且摘要不在文件名旁、需要额外点击才出现的站点用。
        点哪些控件由 source.hashClick 声明（写法与 click 相同）；本函数不做产品特判。
        点击后在可见文本里找长度 32 / 40 / 64 / 128 的十六进制串；恰好一个唯一值才返回，
        多个不同值或一个都没有则返回空，由调用方回退就近刮取或报错。
    .OUTPUTS
        [string] 小写十六进制摘要；取不到时为空串
    #>
    param(
        $Session,
        $HashClickSpecs
    )

    if ($null -eq $Session) { return '' }
    $steps = @()
    foreach ($step in @($HashClickSpecs)) {
        if ($null -ne $step) { $steps += $step }
    }
    if ($steps.Count -eq 0) { return '' }

    foreach ($step in $steps) {
        $stepLabel = Format-LinkSpec -Spec $step
        $stepResult = $null
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $stepResult = Invoke-WinstBrowserClickStep -Session $Session -Spec $step
            if ($stepResult.Clicked) { break }
            Wait-WinstDevToolsMessages -Session $Session -Milliseconds 1500
        }
        if (-not $stepResult.Clicked) { return '' }
        if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
            Write-Host ('  [verbose] 已点击「{0}」以读取页面摘要' -f $stepLabel) -ForegroundColor DarkGray
        }
        Wait-WinstDevToolsMessages -Session $Session -Milliseconds 1500
    }

    $readExpression = @'
(() => {
  var text = '';
  try { text = (document.body && (document.body.innerText || document.body.textContent)) || ''; }
  catch (e) { text = ''; }
  text = String(text || '').replace(/\u00a0/g, ' ');
  var re = /\b([0-9a-fA-F]{128}|[0-9a-fA-F]{64}|[0-9a-fA-F]{40}|[0-9a-fA-F]{32})\b/g;
  var found = [];
  var m;
  while ((m = re.exec(text)) !== null) {
    var h = String(m[1] || '').toLowerCase();
    if (h && found.indexOf(h) < 0) { found.push(h); }
  }
  if (found.length === 1) { return found[0]; }
  return '';
})()
'@

    $raw = Get-WinstDevToolsValue -Session $Session -Expression $readExpression
    $fromPage = ([string]$raw).Trim().ToLowerInvariant()
    if ($fromPage -match '^[0-9a-f]{32}$|^[0-9a-f]{40}$|^[0-9a-f]{64}$|^[0-9a-f]{128}$') {
        # 尽量关掉弹层，避免挡住后续 outerHTML / 其它操作
        $null = Get-WinstDevToolsValue -Session $Session -Expression @'
(() => {
  try {
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, which: 27, bubbles: true }));
  } catch (e) { }
  return true;
})()
'@
        Wait-WinstDevToolsMessages -Session $Session -Milliseconds 300
        return $fromPage
    }
    return ''
}
