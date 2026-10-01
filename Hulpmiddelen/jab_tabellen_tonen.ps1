# Toont alle zichtbare Java-tabellen in Pharmacom met hun kolomkoppen (geen patientgegevens).
# Uitvoeren met 32-bit PowerShell:
#   C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File jab_tabellen_tonen.ps1
Add-Type -ReferencedAssemblies System.Windows.Forms @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class J {
  const string D = @"C:\PharmaPartners\jres\oracle\1.8.0_491\bin\WindowsAccessBridge-32.dll";
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern void Windows_run();
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int isJavaWindow(IntPtr h);
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int getAccessibleContextFromHWND(IntPtr h, out int vm, out long ac);
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int getAccessibleContextInfo(int vm, long ac, byte[] buf);
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern long getAccessibleChildFromContext(int vm, long ac, int i);
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int getAccessibleTableInfo(int vm, long ac, byte[] buf);
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int getAccessibleTableColumnHeader(int vm, long ac, byte[] buf);
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int getAccessibleTableCellInfo(int vm, long at, int r, int c, byte[] buf);
  [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern void releaseJavaObject(int vm, long o);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EP cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  public delegate bool EP(IntPtr h, IntPtr l);
  static string S(byte[] b, int off){ int n=0; while(off+n*2+1<b.Length && (b[off+n*2]!=0||b[off+n*2+1]!=0)) n++; return Encoding.Unicode.GetString(b,off,n*2); }
  public static StringBuilder o = new StringBuilder(); static int nodes; static Dictionary<string,int> roles;
  static string Name(int vm,long ac){ var b=new byte[6188]; if(getAccessibleContextInfo(vm,ac,b)==0) return "?"; return S(b,0); }
  static void Walk(int vm,long ac,int d,string path){
    nodes++; var b=new byte[6188]; if(getAccessibleContextInfo(vm,ac,b)==0) return;
    string role=S(b,4608), st=S(b,5632); int ch=BitConverter.ToInt32(b,6148);
    bool showing=(","+st+",").Contains(",showing,");
    if(!roles.ContainsKey(role)) roles[role]=0; roles[role]++;
    if(role=="table"){
      var ti=new byte[48]; getAccessibleTableInfo(vm,ac,ti);
      int rows=BitConverter.ToInt32(ti,16), cols=BitConverter.ToInt32(ti,20);
      var hi=new byte[48]; string heads="";
      if(getAccessibleTableColumnHeader(vm,ac,hi)!=0){ long hat=BitConverter.ToInt64(hi,32);
        for(int c=0;c<cols;c++){ var ci=new byte[40]; if(getAccessibleTableCellInfo(vm,hat,0,c,ci)!=0){ long cac=BitConverter.ToInt64(ci,0); heads+=Name(vm,cac)+" | "; releaseJavaObject(vm,cac);} } }
      else heads="(geen header)";
      o.AppendLine("TABLE depth="+d+" showing="+showing+" rows="+rows+" cols="+cols+" nodeNr="+nodes+" states="+st+"\n   heads: "+heads);
      return;
    }
    if(!showing) return;
    if(d>80) { o.AppendLine("depth limit"); return; }
    int n=Math.Min(ch,3000);
    for(int i=0;i<n;i++){ long k=getAccessibleChildFromContext(vm,ac,i); if(k==0) continue; Walk(vm,k,d+1,path); releaseJavaObject(vm,k); }
  }
  public static void Run(uint pid){
    var hs=new List<IntPtr>(); EnumWindows((h,l)=>{uint p; GetWindowThreadProcessId(h,out p); if(p==pid&&IsWindowVisible(h)) hs.Add(h); return true;},IntPtr.Zero);
    foreach(var h in hs){ var sb=new StringBuilder(256); GetWindowText(h,sb,256);
      o.AppendLine("WINDOW "+h+" '"+sb+"' java="+isJavaWindow(h));
      if(isJavaWindow(h)==0) continue; int vm; long ac; if(getAccessibleContextFromHWND(h,out vm,out ac)==0) continue;
      nodes=0; roles=new Dictionary<string,int>(); Walk(vm,ac,0,""); releaseJavaObject(vm,ac);
      o.AppendLine("  nodes visited: "+nodes); foreach(var kv in roles) o.Append("  ["+kv.Key+"="+kv.Value+"]"); o.AppendLine(); }
  }
}
"@
[J]::Windows_run()
$t=[DateTime]::Now; while(([DateTime]::Now-$t).TotalMilliseconds -lt 1500){ [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 20 }
$p = Get-Process javaw | ? { $_.MainWindowTitle -like 'Pharmacom*' } | Select -First 1
[J]::Run([uint32]$p.Id)
[J]::o.ToString()

