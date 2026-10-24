#Requires -Version 5.1
<#
    WinstState.Type.ps1  (Winst.Core / Private)

    声明跨模块状态容器，供 Winst.Core 的 Get-WinstState / Set-WinstState 使用。

    为什么用静态 .NET 字典而不是模块变量
    ------------------------------------
    Windows PowerShell 里每个模块各有独立的 $script: 作用域，
    一个模块里的普通模块变量其它模块根本看不到。

    进程级静态字典属于整个 AppDomain，所有模块读到同一份值，
    并且在开发期间 Import-Module -Force 之后仍能保留进程内缓存。

    访问一律通过公开 API，存储方式将来要换也不必改调用点：
        Get-WinstState    Set-WinstState    Test-WinstState
        Remove-WinstState Reset-WinstState
#>

if (-not ('Winst.State' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;

namespace Winst
{
    public static class State
    {
        private static readonly Dictionary<string, object> Values =
            new Dictionary<string, object>(StringComparer.Ordinal);

        private static readonly object Gate = new object();

        public static object Get(string name)
        {
            if (string.IsNullOrEmpty(name)) { return null; }

            lock (Gate)
            {
                object value;
                if (Values.TryGetValue(name, out value)) { return value; }
                return null;
            }
        }

        public static void Set(string name, object value)
        {
            if (string.IsNullOrEmpty(name)) { return; }

            lock (Gate)
            {
                Values[name] = value;
            }
        }

        public static bool Contains(string name)
        {
            if (string.IsNullOrEmpty(name)) { return false; }

            lock (Gate)
            {
                return Values.ContainsKey(name);
            }
        }

        public static bool Remove(string name)
        {
            if (string.IsNullOrEmpty(name)) { return false; }

            lock (Gate)
            {
                return Values.Remove(name);
            }
        }

        public static void Clear()
        {
            lock (Gate)
            {
                Values.Clear();
            }
        }
    }
}
'@ -ErrorAction Stop
}
