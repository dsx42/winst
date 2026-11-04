#Requires -Version 5.1

function Get-WinstBrowserPageHash {
    <#
    .SYNOPSIS
        在无头浏览器会话里读取页面 MD5 弹层 / 可见「哈希值」文案中的摘要。
    .DESCRIPTION
        给 files[0].hashFrom: "page" 且摘要不在文件名旁的站点用（如飞牛官网：MD5 在独立按钮弹出的
        文案「MD5 哈希值：…」里，渲染 DOM 没有 fnos_*.iso 文件名可就近刮取）。先读可见文本；没有则
        点文字含 MD5 的控件、等弹层出现再读。读到多个不同摘要时返回空，由调用方回退就近刮取或报错。
    .OUTPUTS
        [string] 小写十六进制摘要；取不到时为空串
    #>
    param($Session)

    if ($null -eq $Session) { return '' }

    $readExpression = @'
(() => {
  var text = '';
  try { text = (document.body && (document.body.innerText || document.body.textContent)) || ''; }
  catch (e) { text = ''; }
  text = String(text || '').replace(/\u00a0/g, ' ');
  var patterns = [
    /MD5\s*哈希值\s*[:：]\s*([0-9a-fA-F]{32})\b/i,
    /MD5\s*[:：]\s*([0-9a-fA-F]{32})\b/i,
    /哈希值\s*[:：]\s*([0-9a-fA-F]{32}|[0-9a-fA-F]{40}|[0-9a-fA-F]{64}|[0-9a-fA-F]{128})\b/i
  ];
  var found = [];
  for (var p = 0; p < patterns.length; p++) {
    var re = new RegExp(patterns[p].source, 'gi');
    var m;
    while ((m = re.exec(text)) !== null) {
      var h = String(m[1] || '').toLowerCase();
      if (h && found.indexOf(h) < 0) { found.push(h); }
    }
    if (found.length > 0) { break; }
  }
  if (found.length === 1) { return found[0]; }
  return '';
})()
'@

    $raw = Get-WinstDevToolsValue -Session $Session -Expression $readExpression
    $existing = ([string]$raw).Trim().ToLowerInvariant()
    if ($existing -match '^[0-9a-f]{32}$|^[0-9a-f]{40}$|^[0-9a-f]{64}$|^[0-9a-f]{128}$') {
        return $existing
    }

    $stepResult = Invoke-WinstBrowserClickStep -Session $Session -Spec @{ text = 'MD5' }
    if (-not $stepResult.Clicked) { return '' }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host '  [verbose] 已点击「MD5」以读取页面摘要' -ForegroundColor DarkGray
    }
    Wait-WinstDevToolsMessages -Session $Session -Milliseconds 1500

    $raw = Get-WinstDevToolsValue -Session $Session -Expression $readExpression
    $fromModal = ([string]$raw).Trim().ToLowerInvariant()
    if ($fromModal -match '^[0-9a-f]{32}$|^[0-9a-f]{40}$|^[0-9a-f]{64}$|^[0-9a-f]{128}$') {
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
        return $fromModal
    }
    return ''
}
